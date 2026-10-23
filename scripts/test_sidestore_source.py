"""Regression checks for publication and SideStore's numeric hasUpdate branch."""
import io
import json
import plistlib
import unittest
import zipfile
import update_sidestore_source as source


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.document = json.loads((source.ROOT / 'sidestore/source.json').read_text())
        self.beta6 = next(v for v in self.document['apps'][0]['versions'] if '/v0.2.0beta6/' in v['downloadURL'])

    def test_committed_source(self):
        source.validate(self.document)
        self.assertEqual(self.beta6['version'], '0.2.0')
        self.assertEqual(self.beta6['buildVersion'], '19')

    def test_idempotent(self):
        self.assertEqual(source.merge_versions([self.beta6], dict(self.beta6)), [self.beta6])

    def test_build_only_is_rejected(self):
        new = dict(self.beta6, buildVersion='20', downloadURL=self.beta6['downloadURL'] + '-beta7')
        with self.assertRaisesRegex(ValueError, 'Build-only'):
            source.merge_versions([self.beta6], new)
        # InstalledApp.hasUpdate compares semantic version, not CFBundleVersion here.
        self.assertFalse(source.version_key('0.2.0') > source.version_key('0.2.0'))

    def test_next_beta_detectable_and_sorted(self):
        new = dict(self.beta6, version='0.2.1', buildVersion='20', downloadURL=self.beta6['downloadURL'] + '-beta7')
        versions = source.merge_versions([self.beta6], new)
        self.assertEqual([v['version'] for v in versions], ['0.2.1', '0.2.0'])
        self.assertTrue(source.version_key(versions[0]['version']) > source.version_key(self.beta6['version']))
        source.validate(source.make_source(versions))

    def test_replacement_and_rollback_rejected(self):
        for new in [dict(self.beta6, sha256='a' * 64),
                    dict(self.beta6, version='0.1.9', downloadURL='older')]:
            with self.assertRaises(ValueError):
                source.merge_versions([self.beta6], new)

    def test_numeric_order_not_lexical(self):
        self.assertGreater(source.version_key('0.2.10'), source.version_key('0.2.9'))
        with self.assertRaises(ValueError):
            source.version_key('0.2.0-beta.7')

    def test_ipa_identity_size_hash(self):
        buf = io.BytesIO()
        info = dict(CFBundleIdentifier=source.BUNDLE, CFBundleShortVersionString='0.2.1',
                    CFBundleVersion='20', CFBundleSupportedPlatforms=['iPhoneOS'], MinimumOSVersion='18.0')
        with zipfile.ZipFile(buf, 'w') as archive:
            archive.writestr('Payload/TiebaLite.app/Info.plist', plistlib.dumps(info))
        data = buf.getvalue()
        asset = dict(size=len(data), browser_download_url=self.beta6['downloadURL'])
        release = dict(tag_name='v0.2.0beta7', published_at='2026-10-22T00:00:00Z', body='test')
        self.assertEqual(source.inspect_ipa(data, asset, release)['version'], '0.2.1')
        for bad in [dict(asset, size=1), dict(asset, digest='sha256:' + '0' * 64)]:
            with self.assertRaises(ValueError):
                source.inspect_ipa(data, bad, release)


if __name__ == '__main__':
    unittest.main()
