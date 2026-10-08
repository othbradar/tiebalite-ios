"""Reproduce only the synthetic native TBS preparation fixture, without network."""
import argparse
import gc
import json
import os
from pathlib import Path
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-binary', required=True, type=Path)
parser.add_argument('--fixtures', required=True, type=Path)
parser.add_argument('--output', type=Path)
parser.add_argument('--verify', type=Path)
args = parser.parse_args()
if bool(args.output) == bool(args.verify):
    parser.error('Choose exactly one of --output or --verify')
if args.output and args.output.exists():
    parser.error('Output must be a new file')
os.environ['TIEBALITE_NATIVE_REFERENCE'] = str(args.reference_binary.resolve(strict=True))
sys.dont_write_bytecode = True
import read_macho as reference  # noqa: E402
from emulate_tbs import TBSCommonEmulator, TBSResponseEmulator  # noqa: E402
from emulate_common import CommonEmulator  # noqa: E402

signed = []
samples = json.loads((args.fixtures / 'native-ios-common-transform.json').read_text())['cases']
for sample in [samples[0], samples[3]]:
    inputs = dict(sample['input'], api='/c/s/tbs')
    business = {'BDUSS': 'fixture-tbs-session'}
    emulator = CommonEmulator()
    static = emulator.run_static(sample['staticContext'], sample['staticMode'])
    del emulator
    gc.collect()
    emulator = TBSCommonEmulator()
    expected = emulator.run_form(inputs, static, business, sample['metrics'])
    signed.append(dict(name=expected['path'], input=inputs, staticContext=sample['staticContext'],
                       staticMode=sample['staticMode'], metrics=sample['metrics'], business=business, expected=expected))
    del emulator
    gc.collect()

responses = []
scenarios = [
    ('top-level-zero', {'error_code': 0, 'tbs': 'fixture-ready'}),
    ('nested-zero', {'error': {'errno': '0'}, 'tbs': 'fixture-ready'}),
    ('both-zero', {'error_code': '0', 'error': {'errno': 0}, 'tbs': 'fixture-ready'}),
    ('primary-reject', {'error_code': 6, 'error': {'errno': 0}, 'tbs': 'fixture-rejected'}),
    ('nested-reject', {'error_code': 0, 'error': {'errno': 6}, 'tbs': 'fixture-rejected'}),
    ('negative-reject', {'error_code': -1, 'tbs': 'fixture-rejected'}),
    ('missing-code', {'tbs': 'fixture-unconfirmed'}),
    ('null-code', {'error_code': None, 'tbs': 'fixture-unconfirmed'}),
    ('dictionary-code', {'error_code': {}, 'tbs': 'fixture-unconfirmed'}),
    ('missing-tbs', {'error_code': 0}), ('empty-tbs', {'error_code': 0, 'tbs': ''}),
    ('nested-tbs', {'error_code': 0, 'data': {'tbs': 'fixture-unconfirmed'}}),
    ('dictionary-tbs', {'error_code': 0, 'tbs': {'value': 'fixture-unconfirmed'}}),
    ('number-tbs', {'error_code': 0, 'tbs': 42}),
    ('fractional-tbs', {'error_code': 0, 'tbs': 42.75}),
    ('bool-tbs', {'error_code': 0, 'tbs': True}),
    ('whitespace-preserved', {'error_code': 0, 'tbs': ' '}),
    ('string-code-prefix', {'error_code': ' 6 suffix', 'tbs': 'fixture-rejected'}),
    ('empty-code-native-zero', {'error_code': '', 'tbs': 'fixture-ready'}),
    ('not-dictionary', []),
]
for name, value in scenarios:
    raw = json.dumps(value, ensure_ascii=False, separators=(',', ':'))
    emulator = TBSResponseEmulator()
    responses.append(dict(name=name, json=raw, expected=emulator.run_json(raw.encode())))
    del emulator
    gc.collect()
for name, raw in [('invalid-json', '{'), ('empty-body', '')]:
    emulator = TBSResponseEmulator()
    responses.append(dict(name=name, json=raw, expected=emulator.run_json(raw.encode())))
    del emulator
    gc.collect()
output = dict(referenceExecutableSHA256=reference.REFERENCE_SHA256,
              scope='Synthetic native ordinary-form Common/signing and JSON parser -> TBS completion. '
                    'Executes native stringAtPath type conversion and native URL signature/rename allowlists. '
                    'Foundation primitives and runtime providers have closed substitutes; database and '
                    'notification effects are recorded only. Not Live traffic or full account preparation.',
              signingCases=signed, responseCases=responses)
if args.verify:
    assert json.loads(args.verify.read_text()) == output, 'Native TBS fixture drift'
else:
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
print(f'PASS: TBS signed forms ({len(signed)}), JSON/completion ({len(responses)})')
