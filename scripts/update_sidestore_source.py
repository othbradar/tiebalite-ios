#!/usr/bin/env python3
"""Generate a SideStore v1 source from immutable GitHub Release IPA metadata."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import re
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
REPO = 'othbradar/tiebalite-ios'
BASE = f'https://raw.githubusercontent.com/{REPO}/main'
BUNDLE = 'dev.local.tiebaliteios'


def get(url, api=False):
    headers = {'User-Agent': 'TiebaLite-source-generator'}
    if api and os.environ.get('GITHUB_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['GITHUB_TOKEN']
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=90) as response:
        return response.read()


def version_key(version):
    # Deliberately require numeric marketing versions: reliable on stable and develop clients.
    if not re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', version):
        raise ValueError(f'Use a unique numeric X.Y.Z marketing version in the IPA: {version}')
    return tuple(map(int, version.split('.')))


def inspect_ipa(data, asset, release):
    if len(data) != asset['size']:
        raise ValueError('Release asset size mismatch')
    digest = hashlib.sha256(data).hexdigest()
    if asset.get('digest') and asset['digest'] != 'sha256:' + digest:
        raise ValueError('Release asset SHA256 mismatch')
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        names = [n for n in archive.namelist() if re.fullmatch(r'Payload/[^/]+\.app/Info.plist', n)]
        if len(names) != 1:
            raise ValueError('Expected one main application')
        info = plistlib.loads(archive.read(names[0]))
        if info['CFBundleIdentifier'] != BUNDLE or info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
            raise ValueError('Wrong bundle identifier or platform')
        if info.get('MinimumOSVersion') is None:
            raise ValueError('Missing MinimumOSVersion')
        version_key(info['CFBundleShortVersionString'])
        return dict(version=info['CFBundleShortVersionString'], buildVersion=info['CFBundleVersion'],
                    date=release['published_at'], minOSVersion=info['MinimumOSVersion'],
                    localizedDescription=release['tag_name'] + '\n' + (release.get('body') or ''),
                    downloadURL=asset['browser_download_url'], size=len(data), sha256=digest)


def merge_versions(old, new):
    for entry in old:
        if entry['downloadURL'] == new['downloadURL']:
            if entry != new:
                raise ValueError('Published version changed; never replace an existing IPA or metadata silently')
            return old
        if version_key(entry['version']) == version_key(new['version']):
            raise ValueError('Build-only update is not detectable reliably; increment IPA MARKETING_VERSION')
    if old and version_key(new['version']) <= max(version_key(v['version']) for v in old):
        raise ValueError('New release must increase IPA MARKETING_VERSION')
    return sorted(old + [new], key=lambda v: version_key(v['version']), reverse=True)


def make_source(versions):
    latest = versions[0]
    icon = BASE + '/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
    app = dict(name='TiebaLite iOS', bundleIdentifier=BUNDLE, developerName='othbradar',
               subtitle='非官方贴吧客户端 · Beta',
               localizedDescription='原生 iOS/iPadOS 贴吧客户端。此源包含 GitHub 公开测试版本。',
               iconURL=icon, tintColor='9BCBF2', screenshotURLs=[], versions=versions,
               appPermissions={'entitlements': [], 'privacy': [
                   {'name': 'PhotoLibraryAdd',
                    'usageDescription': '将您选择的图片保存到相册，仅添加照片，不读取您的相册。'}]})
    app.update(version=latest['version'], versionDate=latest['date'],
               versionDescription=latest['localizedDescription'],
               downloadURL=latest['downloadURL'], size=latest['size'])
    return dict(name='TiebaLite iOS', identifier='dev.local.tiebaliteios.source',
                sourceURL=BASE + '/sidestore/source.json', website=f'https://github.com/{REPO}',
                apps=[app], news=[])


def validate(source):
    app, = source['apps']
    assert app['bundleIdentifier'] == BUNDLE
    versions = app['versions']
    assert versions and versions == sorted(versions, key=lambda v: version_key(v['version']), reverse=True)
    assert len({v['version'] for v in versions}) == len(versions)
    for v in versions:
        assert isinstance(v['size'], int) and 0 < v['size'] < 2**31
        assert re.fullmatch('[0-9a-f]{64}', v['sha256'])
        assert v['downloadURL'].startswith(f'https://github.com/{REPO}/releases/download/')
        assert isinstance(v['buildVersion'], str) and v['buildVersion']
    assert app['version'] == versions[0]['version']
    assert app['downloadURL'] == versions[0]['downloadURL']
    assert app['size'] == versions[0]['size']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', help='Release tag; defaults to newest published release, including prereleases')
    parser.add_argument('--release-json', type=Path, help='Offline GitHub Release response')
    parser.add_argument('--ipa', type=Path, help='Offline IPA for that Release')
    parser.add_argument('--output', type=Path, default=ROOT / 'sidestore/source.json')
    parser.add_argument('--check', action='store_true', help='Validate committed JSON without network')
    args = parser.parse_args()
    if args.check:
        validate(json.loads(args.output.read_text()))
        print('Source structure/order/legacy fields OK')
        return
    if args.release_json:
        release = json.loads(args.release_json.read_text())
    elif args.tag:
        import urllib.parse
        release = json.loads(get(f'https://api.github.com/repos/{REPO}/releases/tags/' + urllib.parse.quote(args.tag, safe=''), True))
    else:
        releases = json.loads(get(f'https://api.github.com/repos/{REPO}/releases?per_page=100', True))
        release = max((r for r in releases if not r['draft']), key=lambda r: r['published_at'])
    if release['draft'] or (args.tag and args.tag != release['tag_name']):
        raise ValueError('Draft or mismatched release')
    assets = [a for a in release['assets'] if a['name'].endswith('-ios18-arm64-unsigned.ipa')]
    if len(assets) != 1:
        raise ValueError('Expected exactly one ios18 arm64 unsigned IPA; upload asset before retrying')
    asset, = assets
    data = args.ipa.read_bytes() if args.ipa else get(asset['browser_download_url'])
    new = inspect_ipa(data, asset, release)
    old = json.loads(args.output.read_text())['apps'][0]['versions'] if args.output.exists() else []
    source = make_source(merge_versions(old, new))
    validate(source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=args.output.parent, delete=False) as f:
        json.dump(source, f, ensure_ascii=False, indent=2)
        f.write('\n')
    os.replace(f.name, args.output)
    print(f"Validated {release['tag_name']}: {new['version']} ({new['buildVersion']}), {new['size']} bytes")


if __name__ == '__main__':
    main()
