"""Native plain-text request composition oracle; all providers are synthetic."""
import argparse
import base64
import gc
import json
import os
from pathlib import Path
import sys
from google.protobuf import descriptor_pb2, descriptor_pool, json_format, message_factory

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-binary', required=True, type=Path)
parser.add_argument('--fixtures', required=True, type=Path)
parser.add_argument('--output', type=Path)
parser.add_argument('--verify', type=Path)
args = parser.parse_args()
if bool(args.output) == bool(args.verify):
    parser.error('Choose exactly one of --output or --verify')
if args.output and args.output.exists():
    parser.error('Output file must not exist')
os.environ['TIEBALITE_NATIVE_REFERENCE'] = str(args.reference_binary.resolve(strict=True))
sys.dont_write_bytecode = True
import read_macho as reference  # noqa: E402
from emulate_common import CommonEmulator  # noqa: E402
from emulate_common_transform import CommonTransformEmulator  # noqa: E402
from emulate_response import ResponseEmulator  # noqa: E402

def descriptor(offset, length):
    return descriptor_pb2.FileDescriptorProto.FromString(reference.data[offset:offset + length])

client = descriptor(0xa6ef2fc, 151219)
slim = descriptor_pb2.FileDescriptorProto(name='client.proto', package='tbclient', syntax='proto2')
slim.message_type.add().CopyFrom(next(item for item in client.message_type if item.name == 'CommonReq'))
pool = descriptor_pool.DescriptorPool()
pool.Add(slim)
pool.Add(descriptor(0xa6ec6f4, 1706))
pool.Add(descriptor(0xa6ed949, 2161))

business = json.loads((args.fixtures / 'native-ios-business-parameters.json').read_text())['cases']
runtime = json.loads((args.fixtures / 'native-ios-common-transform.json').read_text())['cases'][0]
metrics = dict(api=None, logid=0, cost=0, result=0, uploadBytes=0, downloadBytes=0)
cases = []
for sample in business:
    context = dict(runtime['input'], api='/c/c/thread/add' if sample['kind'] == 'thread' else '/c/c/post/add',
                   sessionValue='fx', secondaryValue='fx', tbs='fixture-tbs')
    emulator = CommonEmulator()
    static = emulator.run_static(runtime['staticContext'], runtime['staticMode'])
    del emulator
    gc.collect()
    emulator = CommonTransformEmulator()
    transformed = emulator.run_signed(context, static, sample['business'], metrics, runtime['metadata'])
    name = 'tbclient.AddThread.AddThreadReqIdl' if sample['kind'] == 'thread' else 'tbclient.AddPost.AddPostReqIdl'
    message = message_factory.GetMessageClass(pool.FindMessageTypeByName(name))()
    json_format.ParseDict({'data': dict(sample['business'], common=transformed['signedCommon'])}, message, ignore_unknown_fields=True)
    cases.append(dict(sample, input=context, expectedCommon=transformed['signedCommon'],
                      wireBase64=base64.b64encode(message.SerializeToString(deterministic=True)).decode('ascii')))
    del emulator
    gc.collect()
emulator = ResponseEmulator()
empty_response = emulator.run_response(0, {}, raw=b'')
del emulator
gc.collect()
output = dict(referenceExecutableSHA256=reference.REFERENCE_SHA256,
              scope='Compose the separately native-replayed plain-text business fields with actual native '
                    'dynamic/signing methods and independent native IDL descriptor encoding. Runtime '
                    'providers are explicit synthetic values. No account/SDK initialization, HTTP execution, '
                    'media upload, verification UI, posting, or moderation observation. Separately executes '
                    'the native parser with an empty body, which fails before calling IDL.',
              staticContext=runtime['staticContext'], staticMode=runtime['staticMode'], metadata=runtime['metadata'],
              metrics=metrics, cases=cases, emptyResponse=empty_response)
if args.verify:
    assert json.loads(args.verify.read_text()) == output, 'Native client fixture drift'
else:
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
print(f'PASS: native composed plain-text requests ({len(cases)}), empty response (1)')
