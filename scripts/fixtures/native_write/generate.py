"""Reproduce bounded native business and IDL fixtures without running an iOS app.

The only executable reference code runs inside Unicorn, with explicit synthetic
inputs and a closed set of host substitutes. No URLSession or socket is provided.
Unknown calls stop execution. No account data, SDK keys, or device IDs are read.
"""
import argparse
import base64
import gc
import json
import os
import sys
from pathlib import Path

from google.protobuf import descriptor_pb2, descriptor_pool, json_format, message_factory

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-binary', required=True, type=Path)
parser.add_argument('--output', type=Path, help='Must be a new or empty directory')
parser.add_argument('--verify', type=Path, help='Compare existing fixtures without writing')
args = parser.parse_args()
if bool(args.output) == bool(args.verify):
    parser.error('Choose exactly one of --output or --verify')
if args.output and args.output.exists() and any(args.output.iterdir()):
    parser.error('Output directory must be empty')
os.environ['TIEBALITE_NATIVE_REFERENCE'] = str(args.reference_binary.resolve(strict=True))
sys.dont_write_bytecode = True

# Imported after the reference path is supplied; read_macho validates SHA256 first.
import read_macho as reference  # noqa: E402
from emulate_reply import Emulator  # noqa: E402
from emulate_thread import ThreadEmulator  # noqa: E402
from emulate_account import AccountEmulator, HeaderEmulator  # noqa: E402
from emulate_http import HTTPEmulator  # noqa: E402
from emulate_signing import CommonSigningEmulator  # noqa: E402
from emulate_response import ResponseEmulator  # noqa: E402
from emulate_common import CommonEmulator  # noqa: E402
from emulate_dynamic_common import DynamicCommonEmulator  # noqa: E402
from emulate_common_transform import CommonTransformEmulator  # noqa: E402
from emulate_account_name import AccountNameEmulator  # noqa: E402
from emulate_cookies import CookieEmulator  # noqa: E402


def descriptor(offset, length):
    return descriptor_pb2.FileDescriptorProto.FromString(reference.data[offset:offset + length])


def schema_pool():
    client = descriptor(0xa6ef2fc, 151219)
    # client.proto contains unrelated legacy json_name collisions. Only CommonReq
    # belongs to these request envelopes; retain its exact field descriptors.
    slim = descriptor_pb2.FileDescriptorProto(name='client.proto', package='tbclient', syntax='proto2')
    slim.message_type.add().CopyFrom(next(m for m in client.message_type if m.name == 'CommonReq'))
    pool = descriptor_pool.DescriptorPool()
    pool.Add(slim)
    pool.Add(descriptor(0xa6ec6f4, 1706))
    pool.Add(descriptor(0xa6ed949, 2161))
    return pool


def business_cases():
    cases = []
    scenarios = [
        ('root', 'threadReply', {}, {}, 'threadPage'),
        ('floor', 'floorReply', {'replyLevel': 1}, {0: '301', 1: '301', 2: '7', 13: '42'}, 'threadPage'),
        ('subpost', 'subpostReply', {'subPostId': '302', 'replyContainer': 2, 'replyLevel': 2},
         {0: '301', 1: '302', 2: '7', 13: '42'}, 'subposts'),
    ]
    for name, kind, model, stack, container in scenarios:
        emulator = Emulator()
        result = emulator.run(model, stack)
        if result['interceptedLoadCount'] != 1:
            raise AssertionError('Native reply did not reach exactly one intercepted send')
        cases.append(dict(name=name, kind=kind, title='', content='Synthetic reply', container=container,
                          pageEntryType=0, replyCount=stack.get(2), entranceType=None,
                          business={k: str(v) for k, v in result['params'].items()}, interceptedLoadCount=1))
        del emulator
        gc.collect()
    for title in ['Fixture title', '']:
        emulator = ThreadEmulator()
        result = emulator.run_thread({'title': title})
        cases.append(dict(name='thread-title' if title else 'thread-no-title', kind='thread', title=title,
                          content='Synthetic thread', container=None, pageEntryType=None, replyCount=None,
                          entranceType=1, business=result, interceptedLoadCount=0))
        del emulator
        gc.collect()
    return cases


def encoding_cases(cases):
    common = {'_client_type': '1', '_client_version': '22.11.1', '_timestamp': '9007199254740993',
              'BDUSS': 'fixture-session', 'stoken': 'fixture-token', 'scr_w': '393.0',
              'scr_h': '852.0', 'scr_dip': '3.0', 'sign': 'fixture-sign'}
    post = dict(cases[0]['business'])
    thread = {'fid': '9', 'kw': 'FixtureForum', 'title': 'Fixture title', 'content': 'Synthetic thread',
              'anonymous': '0', 'tbs': 'fixture-tbs', 'name_show': 'FixtureName', 'show_custom_figure': '0',
              'sig': 'fixture-business-sig', 'floor': '0'}
    pool = schema_pool()
    result = []
    for name, kind, command, business, proto_name in [
        ('post-basic', 'threadReply', 309731, post, 'tbclient.AddPost.AddPostReqIdl'),
        ('post-empty-presence', 'threadReply', 309731, dict(post, v_fid='', v_fname=''), 'tbclient.AddPost.AddPostReqIdl'),
        ('thread-schema', 'thread', 309730, thread, 'tbclient.AddThread.AddThreadReqIdl'),
    ]:
        message = message_factory.GetMessageClass(pool.FindMessageTypeByName(proto_name))()
        json_format.ParseDict({'data': dict(business, common=common)}, message, ignore_unknown_fields=True)
        wire = message.SerializeToString(deterministic=True)
        result.append(dict(name=name, kind=kind, command=command, common=common, business=business,
                           wireBase64=base64.b64encode(wire).decode('ascii')))
    return result


def http_cases(encoded):
    result = []
    for sample, log_id, state in [(encoded[0], 0, None), (encoded[0], -1, None),
                                  (encoded[0], 9007199254740993, 'fixture-state'),
                                  (encoded[2], 42, 'fixture-thread-state')]:
        emulator = HTTPEmulator()
        headers = emulator.headers(sample['command'], log_id, 'FixtureNativeAgent',
                                   {'svcp_stk': state} if state else {})
        part = emulator.file_part(base64.b64decode(sample['wireBase64']))
        if part['body'] != base64.b64decode(sample['wireBase64']):
            raise AssertionError('Native multipart method changed the supplied bytes')
        result.append(dict(kind=sample['kind'], encodingCase=sample['name'], clientLogID=log_id,
                           state=state, userAgent='FixtureNativeAgent', nativeHeaders=headers,
                           partHeaders=part['headers'], partBase64=sample['wireBase64']))
        del emulator
        gc.collect()
    return result


def signing_cases(cases):
    common = {'_client_type': '1', '_client_version': '22.11.1', 'BDUSS': 'fixture-session',
              'stoken': 'fixture-token', '_timestamp': '9007199254740993', 'tbs': 'fixture-common-tbs'}
    business = dict(cases[0]['business'], content='合成文字 + & 😀', floor='7')
    metadata = dict(packageVersion='fixture-package', experimentHits='fixture-hit', experimentMisses='fixture-miss')
    scenarios = [
        ('reply', 'threadReply', business, metadata, None),
        ('after-sign-metadata', 'threadReply', business,
         dict(metadata, packageVersion='fixture-package-new', experimentHits='fixture-hit-new'), None),
        ('nil-metadata', 'threadReply', business,
         dict(packageVersion=None, experimentHits=None, experimentMisses=None), None),
        ('unused-common-sig', 'threadReply', business, metadata, 'fixture-opaque'),
        ('thread', 'thread', cases[3]['business'], metadata, None),
    ]
    pool = schema_pool()
    result = []
    for name, kind, fields, annotations, opaque in scenarios:
        emulator = CommonSigningEmulator()
        prepared = emulator.prepare(common, fields, annotations, opaque)
        message_name = 'tbclient.AddThread.AddThreadReqIdl' if kind == 'thread' else 'tbclient.AddPost.AddPostReqIdl'
        message = message_factory.GetMessageClass(pool.FindMessageTypeByName(message_name))()
        json_format.ParseDict({'data': dict(fields, common=prepared)}, message, ignore_unknown_fields=True)
        result.append(dict(name=name, kind=kind, common=common, business=fields, metadata=annotations,
                           opaqueSignature=opaque, expectedCommon=prepared,
                           wireBase64=base64.b64encode(message.SerializeToString(deterministic=True)).decode('ascii')))
        del emulator
        gc.collect()
    return result


def account_name_cases():
    baseline = dict(accountID='42', profileID='42', cachedName='Old fixture',
                    displayName='New fixture', loginName='Login fixture')
    scenarios = [
        ('changed', {}), ('unchanged', dict(cachedName='New fixture')),
        ('nil-display', dict(displayName=None)), ('empty-display', dict(displayName='')),
        ('no-names', dict(displayName=None, loginName=None)), ('empty-both', dict(displayName='', loginName='')),
        ('wrong-user', dict(profileID='43')), ('no-user', dict(accountID=None)),
        ('no-cached-name', dict(cachedName=None)), ('whitespace-is-preserved', dict(displayName=' ')),
        ('literal-unicode-difference', dict(cachedName='\u00e9', displayName='e\u0301')),
    ]
    result = []
    for name, changes in scenarios:
        context = dict(baseline, **changes)
        emulator = AccountNameEmulator()
        result.append(dict(name=name, input=context, expected=emulator.run_name(context)))
        del emulator
        gc.collect()
    return result


def account_cases():
    result = []
    scenarios = [
        ('warm', '42', {'42_tbs': 'fixture-warm'}, {'TBS': 'fixture-database', 'BDUSS': 'fixture-session'}),
        ('database', '42', {}, {'TBS': 'fixture-database', 'BDUSS': 'fixture-session'}),
        ('missing', '42', {}, {'TBS': '', 'BDUSS': 'fixture-session'}),
        ('no-login-record', '42', {}, None),
        ('signed-out', '', {'42_tbs': 'fixture-warm'}, {'TBS': 'fixture-database', 'BDUSS': 'fixture-session'}),
        ('wrong-account-cache', '43', {'42_tbs': 'fixture-warm'}, {'TBS': '', 'BDUSS': 'fixture-other-session'}),
    ]
    for name, uid, cached, database in scenarios:
        emulator = AccountEmulator()
        result.append(dict(name=name, uid=uid, cache=cached, database=database,
                           **emulator.run_account(uid, cached, database)))
        del emulator
        gc.collect()
    return result


def header_cases():
    result = []
    for value in [None, 'unrelated=fixture-value; Path=/', '__ymg_scsc=fixture-first; Path=/',
                  '__ymg_scsc=; Path=/', '__ymg_scsc=; __ymg_scsc=fixture-second; Path=/',
                  '__ymg_scsc=fixture-first; __ymg_scsc=fixture-second; Path=/']:
        emulator = HeaderEmulator()
        result.append(dict(setCookie=value, expected=emulator.run_header({'Set-Cookie': value} if value else {})))
        del emulator
        gc.collect()
    return result


def response_cases():
    emulator = ResponseEmulator()
    codes = [0, -1, 1, 4, 5, 6, 7, 1990055, 227001, 220015, 220034, 230277, 1211067,
             3250000, 3250001, 3250002, 3250003, 3250004, 3250005, 3250012, 3250013, 999999]
    predicates = [dict(code=code, matches=emulator.predicates(code)) for code in codes]
    actions = []
    for code in [0, 1, 3250016, 3250017, 3250018, 3250020, 3250021, 3250022, 3250023, 3250024]:
        for value in [None, '', 'fixture-pass']:
            actions.append(dict(code=code, passValue=value, **emulator.run_pass(code, value)))
    parser = []
    for code, body in [(0, dict(pid='401', tid='101')), (0, dict(pid='401', tid='101',
                       info=dict(need_vcode='1', vcode_type='2'), anti=dict(vcode_type='2'))),
                       (1, dict(info=dict(block_content='fixture-denial')))]:
        parser.append(dict(code=code, body=body, **emulator.run_response(code, body)))
    return dict(predicateCases=predicates, accountActionCases=actions, parserCases=parser)


def response_decoding_cases():
    # Independent reference descriptors, not the checked-in Swift schema. Strip
    # unrelated presentation fields only; preserve exact selected descriptors.
    pool = descriptor_pool.DescriptorPool()
    client = descriptor(0xa6ef2fc, 151219)
    slim = descriptor_pb2.FileDescriptorProto(name='client.proto', package='tbclient', syntax='proto2')
    keep = ['Error', 'PostAntiInfo', 'AccessState', 'UserSessionInfo', 'VcodeInfo', 'VcodeExtra']
    for message in client.message_type:
        if message.name in keep:
            slim.message_type.add().CopyFrom(message)
    pool.Add(slim)
    for offset, length in [(0xa6ece2f, 1193), (0xa6ee253, 964)]:
        full = descriptor(offset, length)
        subset = descriptor_pb2.FileDescriptorProto(name=full.name, package=full.package, syntax='proto2')
        subset.dependency.append('client.proto')
        for message in full.message_type:
            if message.name.endswith('ResIdl'):
                subset.message_type.add().CopyFrom(message)
            elif message.name == 'DataRes':
                selected = subset.message_type.add(name=message.name)
                for field in message.field:
                    if field.name in ['tid', 'pid', 'info', 'anti']:
                        selected.field.add().CopyFrom(field)
        pool.Add(subset)
    fixture_inputs = [
        ('post-success', 'AddPost', 0, dict(tid='101', pid='401')),
        ('post-metadata-success', 'AddPost', 0, dict(tid='101', pid='401',
             info=dict(need_vcode='1', vcode_type='2', pass_token='fixture-pass'), anti=dict(vcode_type='2'))),
        ('post-error-with-ids', 'AddPost', 5, dict(tid='101', pid='401', info=dict(vcode_md5='fixture-vcode'))),
        ('post-account-verification', 'AddPost', 3250020, dict(info=dict(pass_token='fixture-pass'))),
        ('post-account-missing-material', 'AddPost', 3250020, dict(info=dict(pass_token=''))),
        ('post-forbidden', 'AddPost', 3250001, dict(info=dict(block_content='fixture-denial'))),
        ('post-unknown-error', 'AddPost', 999999, {}),
        ('post-negative-code', 'AddPost', -1, dict(tid='101', pid='401')),
        ('post-missing-data', 'AddPost', 0, None),
        ('post-missing-id', 'AddPost', 0, dict(tid='101')),
        ('post-wrong-thread', 'AddPost', 0, dict(tid='102', pid='401')),
        ('thread-success', 'AddThread', 0, dict(tid='501', pid='601')),
        ('thread-error', 'AddThread', 6, dict(anti=dict(vcode_md5='fixture-vcode'))),
    ]
    action_names = {'deleteAccountAndGotoLogin': 'reauthenticate', 'bindMobile:': 'bindMobile',
                    'verifyID:': 'verifyIdentity', 'modifyPWD': 'changePassword', 'verifyFace': 'verifyFace'}
    result = []
    emulator = ResponseEmulator()
    for name, kind, code, body in fixture_inputs:
        message = message_factory.GetMessageClass(pool.FindMessageTypeByName(f'tbclient.{kind}.{kind}ResIdl'))()
        contents = dict(error=dict(errorno=code, errmsg='fixture-error'))
        if body is not None:
            contents['data'] = body
        json_format.ParseDict(contents, message)
        payload = body or {}
        action = emulator.run_pass(code, payload.get('info', {}).get('pass_token'))['actions']
        categories = emulator.predicates(code)
        result.append(dict(name=name, kind=kind, wireBase64=base64.b64encode(message.SerializeToString(
            deterministic=True)).decode('ascii'), errorCode=code, hasPayload=body is not None,
            threadID=payload.get('tid', ''), postID=payload.get('pid', ''),
            accountAction=action_names[action[0]] if action else None, category=categories[0] if categories else None))
    return result


def dynamic_common_cases():
    baseline = dict(sampleID='fixture-dynamic', hasBrowseModeProvider=True, browseMode='1',
                    clientID='fixture-client', extra='fixture-extra', personalizedSwitch='1',
                    storedPersonalizedSwitch='0', networkType='1', userAgent='FixtureIOSAgent',
                    sessionValue='fx', secondaryValue='fx', opaqueSDKValue='fixture-sdk', tbs='fx',
                    diac='fixture-diac', launchScheme='fixture-launch', launchType=2,
                    timestampSeconds=1700000000.125, activeTimestampSeconds=1699999000.25,
                    signOptimizationEnabled=False, signForumOnly=False, signAll=False,
                    keepAlive=True, smallFlow=False, api='c/c/post/add')
    metrics = dict(api='c/f/pb/page', logid=9007199254740993, cost=0.125, result=-1,
                   uploadBytes=128, downloadBytes=512)
    static = {'_client_type': '1', 'sample_id': 'static'}
    business = {'tid': '101'}
    empty = {key: '' for key, value in baseline.items() if isinstance(value, str) and key != 'api'}
    missing = dict.fromkeys(empty)
    scenarios = [
        ('standard-full', {}), ('standard-empty', empty), ('standard-null', missing),
        ('standard-local-personalized', dict(personalizedSwitch='', storedPersonalizedSwitch='0')),
        ('standard-no-browse-provider', dict(hasBrowseModeProvider=False, browseMode=None)),
        ('optimized-full', dict(signOptimizationEnabled=True, signAll=True)),
        ('optimized-empty', dict(empty, signOptimizationEnabled=True, signAll=True)),
        ('optimized-null', dict(missing, signOptimizationEnabled=True, signAll=True)),
        ('optimized-local-personalized', dict(personalizedSwitch=None, storedPersonalizedSwitch='0',
                                               signOptimizationEnabled=True, signAll=True)),
        ('forum-only-uses-standard-write', dict(signOptimizationEnabled=True, signForumOnly=True)),
        ('disabled-ignores-coverage', dict(signAll=True)),
        ('thread-optimized', dict(api='c/c/thread/add', signOptimizationEnabled=True, signAll=True)),
        ('small-flow', dict(keepAlive=False, smallFlow=True)),
        ('numeric-rounding', dict(timestampSeconds=1.2345, activeTimestampSeconds=1.2355,
                                  launchType=18446744073709551615)),
    ]
    inputs = [(name, dict(baseline, **changes), business, metrics) for name, changes in scenarios]
    for optimized in [False, True]:
        context = dict(baseline, signOptimizationEnabled=optimized, signAll=optimized)
        prefix = 'optimized' if optimized else 'standard'
        inputs.extend([
            (prefix + '-logout', context, dict(business, BDUSS_LOGOUT='fx-out'), metrics),
            (prefix + '-no-previous-api', context, business, dict(metrics, api=None)),
            (prefix + '-empty-previous-api', context, business, dict(metrics, api='')),
            (prefix + '-zero-metrics', context, business, dict(metrics, logid=0, cost=0,
                                                              result=0, uploadBytes=0, downloadBytes=0)),
            (prefix + '-unsigned-metrics', context, business,
             dict(metrics, logid=18446744073709551615, uploadBytes=4294967295, downloadBytes=4294967295)),
        ])
    result = []
    for name, context, request, previous in inputs:
        emulator = DynamicCommonEmulator()
        result.append(dict(name=name, input=context, staticFields=static, business=request, metrics=previous,
                           expected=emulator.run_dynamic(context, static, request, previous)))
        del emulator
        gc.collect()
    return result


def common_transform_cases(business_samples, static_samples, dynamic_samples):
    static = next(sample['steps'][0] for sample in static_samples if sample['name'] == 'privacy-shown')
    dynamic = next(sample for sample in dynamic_samples if sample['name'] == 'standard-full')
    metadata = dict(packageVersion='fixture-package', experimentHits='fixture-hit', experimentMisses='fixture-miss')
    result = []
    pool = schema_pool()
    for optimized in [False, True]:
        for label, annotations in [('metadata', metadata), ('changed-metadata', dict(metadata, experimentHits='new-hit')),
                                    ('nil-metadata', dict.fromkeys(metadata))]:
            context = dict(dynamic['input'], signOptimizationEnabled=optimized, signAll=optimized)
            fields = business_samples[0]['business']
            emulator = CommonTransformEmulator()
            expected = emulator.run_signed(context, static['expected'], fields, dynamic['metrics'], annotations)
            message = message_factory.GetMessageClass(pool.FindMessageTypeByName('tbclient.AddPost.AddPostReqIdl'))()
            json_format.ParseDict({'data': dict(fields, common=expected['signedCommon'])}, message, ignore_unknown_fields=True)
            result.append(dict(name=('optimized-' if optimized else 'standard-') + label,
                               staticContext=static['input'], staticMode=static['mode'], input=context,
                               business=fields, metrics=dynamic['metrics'], metadata=annotations, expected=expected,
                               wireBase64=base64.b64encode(message.SerializeToString(deterministic=True)).decode('ascii')))
            del emulator
            gc.collect()
    return result


def static_common_cases():
    baseline = dict(clientVersion='22.11.1', systemVersion='FixtureOS', deviceScore='fixture-score',
                    deviceFamily='FixtureFamily', devicePlatform='FixturePlatform', channel='fixture-channel',
                    cuid='fixture-cuid', legoVersion='fixture-lego', browserCuid='fixture-bba-cuid',
                    browserInstanceID='fixture-bba-iid', advertisingID='fixture-idfa', sampleID='fixture-sample',
                    vendorID='fixture-idfv', mac='fixture-mac', eventDay='20260102', sdkVersion='fixture-sdk',
                    frameworkVersion='fixture-core', gameVersion='fixture-game', pureMode='0', miniAppMode='1',
                    privacyPolicyShown=False, screenWidth=393.0, screenHeight=852.0, screenScale=3.0, imageQuality=2)
    permitted = dict(baseline, privacyPolicyShown=True)
    changed = dict(permitted, systemVersion='changed-os', channel='changed-channel', cuid='changed-cuid',
                   browserCuid='changed-bba', browserInstanceID='changed-iid', advertisingID='changed-idfa',
                   sampleID='changed-sample', pureMode='3', miniAppMode='4', screenWidth=820.0, screenScale=2.0)
    missing = dict(permitted, browserCuid=None, browserInstanceID=None, advertisingID=None, vendorID=None,
                   mac=None, sampleID=None, legoVersion=None, sdkVersion=None, pureMode=None, miniAppMode=None)
    scenarios = [
        ('privacy-not-shown', [('recomputed', baseline)]),
        ('privacy-shown', [('recomputed', permitted)]),
        ('empty-identifiers', [('recomputed', dict(permitted, browserCuid='', browserInstanceID='', advertisingID=''))]),
        ('missing-optional-providers', [('recomputed', missing)]),
        ('numeric-format', [('recomputed', dict(permitted, screenWidth=820.25, screenHeight=1180.75,
                                               screenScale=2.25, imageQuality=-2))]),
        ('cache-provider-change', [('cached', permitted), ('cached', changed)]),
        ('cache-id-removal', [('cached', permitted), ('cached', dict(changed, advertisingID=''))]),
        ('cache-privacy-transition', [('cached', baseline), ('cached', permitted),
                                      ('cached', dict(changed, privacyPolicyShown=False))]),
        ('switch-paths', [('cached', permitted), ('recomputed', changed), ('cached', changed)]),
    ]
    result = []
    for name, steps in scenarios:
        emulator = CommonEmulator()
        result.append(dict(name=name, steps=[dict(mode=mode, input=context, expected=emulator.run_static(context, mode))
                                             for mode, context in steps]))
        del emulator
        gc.collect()
    return result


def cookie_cases():
    scenarios = [
        ('wifi-enabled', 1, True, False, False, None),
        ('wifi-disabled', 1, False, True, False, None),
        ('cellular-enabled', 2, False, True, False, None),
        ('cellular-disabled', 2, True, False, False, None),
        ('offline', 0, True, True, False, None),
        ('unknown-network', 3, True, True, False, None),
        ('negative-network', -1, True, True, False, None),
        ('small-flow-only', 0, False, False, True, 'fx'),
        ('both', 1, True, True, True, 'fx'),
        ('small-flow-disabled', 0, False, False, False, 'fx'),
        ('small-flow-empty', 0, False, False, True, ''),
        ('small-flow-nil', 0, False, False, True, None),
    ]
    cases = []
    for name, status, wifi, cellular, small_flow, value in scenarios:
        inputs = dict(networkStatus=status, wifiKeepAlive=wifi, cellularKeepAlive=cellular,
                      smallFlow=small_flow, smallFlowValue=value)
        emulator = CookieEmulator()
        cases.append(dict(name=name, input=inputs, cookies=emulator.run(inputs)))
        del emulator
        gc.collect()
    return cases


cases = business_cases()
static_samples = static_common_cases()
dynamic_samples = dynamic_common_cases()
outputs = {
    'native-ios-business-parameters.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Offline native method execution for explicit synthetic plain-text inputs. Foundation/account/location/upload '
              'dependencies mocked; no SDK, live traffic, rich-text conversion or moderation observation. Reply scene=1, '
              'replyFrom=0; thread entranceType=1, composeType=0, no tabs/poll/media.', cases=cases),
    'native-ios-request-encoding.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Synthetic schema/encoding fixtures. post-basic business fields come from offline emulation with explicit '
              'mocks; thread-schema is NOT a native thread-builder observation. No live requests or SDK context are represented.',
        cases=encoding_cases(cases)),
    'native-ios-account-state.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Offline native newGetUserTBS and ymgScscParseFromResponseHeader execution. Synthetic memory/KV/DB and '
              'Foundation substitutes; TBS fetch is intercepted, not executed. No login, persistence or live traffic.',
        accountCases=account_cases(), headerCases=header_cases()),
    'native-ios-http-envelope.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Offline native addExtraHttpHeaders and appendPartWithFileData execution. Synthetic UA, log IDs and '
              'response-state inputs. File-part arguments data/data/image/jpeg are from the statically traced '
              'IDPServerAPI -> BBAAFNetworking path. No system UA, cookies, SDK, final network or moderation claim.',
        cases=http_cases(encoding_cases(cases))),
    'native-ios-signing.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Native merge/sign/return block 0x1024b2f94..0x1024b3458 with explicit pre-populated Common and '
              'business dictionaries. Executes the native HTTPS stoken filter and NSString MD5 formatter; '
              'Foundation and CC_MD5 have closed substitutes. Runtime account/device/SDK providers are not '
              'executed. Optional common.sig provider is an explicit opaque mock; IDL omits it. No Live traffic.',
        cases=signing_cases(cases)),
    'native-ios-response-rules.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Native UEG scalar error predicates and UEGPass branching with synthetic NSError data. '
              'Account/verification UI effects are intercepted, not executed. Parser state cases execute '
              'TBCServerAPI.parseBodyIsProtobuf with an explicit IDL decoder substitute and HTTP-success state. '
              'These do not execute the full model/UEG/UI completion or prove posting success. No network.',
        **response_cases()),
    'native-ios-response-decoding.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Synthetic receipt bytes encoded from selected fields of native AddPost/AddThread response descriptors. '
              'Error categories/account actions replay native predicates with intercepted UI effects. '
              'Not captured Live responses, full UEG processing or evidence of moderation retention.',
        cases=response_decoding_cases()),
    'native-ios-static-common.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Native commonStaticParameters cached branch and commonStaticParametersNew recomputed branch. '
              'Explicit synthetic OS/SDK/device/sync/consent getter results and date-formatter output. '
              'Does not run the actual providers, initialize SDKs or read device/account state. No Live traffic.',
        cases=static_samples),
    'native-ios-dynamic-common.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Native HTTPS/Protobuf pre-sign Common transformation, standard and optimized branches, with '
              'explicit synthetic static/account/SDK/config/clock getters. Executes native safeSetString helper '
              'and previous-request metrics consumption. No actual runtime providers, SDK initialization, '
              'signing, final network request or Live traffic are executed.',
        cases=dynamic_samples),
    'native-ios-common-transform.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Native dynamic Common through merge/sign/signed-return for HTTPS/Protobuf, using separately replayed '
              'static Common and explicit synthetic runtime providers. Includes both native config branches, '
              'metadata presence/absence and independent descriptor encoding. No real SDK/account/clock '
              'initialization, Live traffic, full App execution or moderation result.',
        cases=common_transform_cases(cases, static_samples, dynamic_samples)),
    'native-ios-cookies.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Native addExtraCookieParams, shouldKeepAlive and shouldGoSmallFlow with synthetic network/config '
              'providers. Foundation cookie creation is substituted; no global cookie jar, HTTP DNS, account '
              'data or network is accessed. Records only selected request name/value pairs.',
        cases=cookie_cases()),
    'native-ios-account-name.json': dict(
        referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Native TBCPersonalInfoModel completion UID guard and nickname selection/update through its '
              'nickname boundary. Synthetic profile/account fields; unrelated profile effects, database writes '
              'and notifications intercepted. No actual profile request, Passport SDK, account store or network.',
        cases=account_name_cases()),
}
for name, contents in outputs.items():
    if args.verify:
        if json.loads((args.verify / name).read_text()) != contents:
            raise AssertionError(f'Native reference fixture drift: {name}')
    else:
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output / name).write_text(json.dumps(contents, ensure_ascii=False, indent=2) + '\n')
print('PASS: native business (5), independent IDL (3), account (6), response header (6), '
      'HTTP envelope (4), signing (5), error predicates (22), account actions (30), parser state (3), '
      'response decoding (13), static Common (9 sequences / 15 steps), dynamic Common (24), '
      'signed Common (6), account names (11), request cookies (12) cases')
