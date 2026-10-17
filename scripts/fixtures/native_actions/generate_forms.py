"""Replay the iOS 22.11.1 ordinary-form Common path for likes/unlikes, offline.

Runtime providers and Foundation primitives are synthetic; the native URL
signature/rename decisions and signing instructions execute in Unicorn.
"""
import argparse
import gc
import json
import os
from pathlib import Path
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-binary', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
os.environ['TIEBALITE_NATIVE_REFERENCE'] = str(args.reference_binary.resolve(strict=True))
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'native_write'))
from emulate_tbs import TBSCommonEmulator  # noqa: E402
from emulate_common import CommonEmulator  # noqa: E402
import read_macho as reference  # noqa: E402

root = Path(__file__).resolve().parents[3]
sample = json.loads((root / 'TestSupport/Fixtures/API/Write/native-ios-common-transform.json').read_text())['cases'][0]
# Caller evidence: ordinary thread Social.processAttitude 0x101aef7d4 -> type 3;
# ordinary PB TopBar.zanAction 0x102e6e488 -> type 1. FP-without-floor
# branch 0x102e6e610 uses type 2 and is not an ordinary PB reply.
results = []
for kind, business in [
    ('thread', dict(thread_id='10', post_id='1', forum_id='9', obj_type='3', agree_type='2', op_type='0')),
    ('post', dict(thread_id='10', post_id='11', forum_id='9', obj_type='1', agree_type='2', op_type='0')),
    ('post', dict(thread_id='10', post_id='11', forum_id='9', obj_type='1', agree_type='2', op_type='1')),
]:
    path = '/c/c/agree/opAgree'
    context = dict(sample['input'], api=path)
    metrics = dict(api=None, logid=0, cost=0, result=0, uploadBytes=0, downloadBytes=0)
    emulator = CommonEmulator()
    static = emulator.run_static(sample['staticContext'], sample['staticMode'])
    del emulator
    gc.collect()
    emulator = TBSCommonEmulator()
    emulator.metadata = {}
    emulator.additional_signature = None
    emulator.additional_signature_inputs = []
    emulator.signed = None
    emulator.run_dynamic(context, static, business, metrics, include_request_params=True)
    assert emulator.signed is not None, 'missing native form return'
    results.append(dict(kind=kind, path=path, business=business, input=context, staticContext=sample['staticContext'],
                        staticMode=sample['staticMode'], expected=emulator.signed))
    del emulator
    gc.collect()
args.output.write_text(json.dumps(dict(referenceSHA256=reference.REFERENCE_SHA256, cases=results), ensure_ascii=False, indent=2) + '\n')
print('PASS: native action form replay; no network')
