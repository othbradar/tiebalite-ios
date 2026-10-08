"""Generate or verify synthetic native reply-follow-up parameter observations."""
import argparse
import gc
import json
import os
from pathlib import Path
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-binary', required=True, type=Path)
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
from emulate_reply_followup import ReplyFollowupEmulator  # noqa: E402

base = dict(kz='101', r='30', back='1', lz='1', pn='7', sort_type='2',
            mark_type='9', last_pid='11', custom='preserve-me')
scenarios = [
    ('floor', 'floor-receipt', dict(threadID='101', postID='430001')),
    ('floor', 'floor-keeps-encoded-string', dict(threadID='101', postID='00430001')),
    ('floor', 'floor-builder-nil-inputs', dict(threadID=None, postID=None)),
    ('floor', 'floor-builder-empty-inputs', dict(threadID='', postID='')),
    ('thread', 'thread-drops-old-page-selection', dict(base=base, postID='430001')),
    ('thread', 'thread-normalizes-numeric-id', dict(base=base, postID='00430001')),
    ('thread', 'thread-folded-comments-flag', dict(base=base, postID='430001', includesFoldedComments=True)),
    ('thread', 'thread-nil-receipt-builder', dict(base=base, postID=None)),
    ('thread', 'thread-empty-base', dict(base={}, postID='430001')),
    ('thread', 'thread-nil-base', dict(base=None, postID='430001')),
    ('thread', 'thread-keeps-64-bit-id', dict(base=base, postID='9007199254740993')),
]
for state in [0, 1, 2, 3, 4]:
    scenarios.append(('load', f'load-state-{state}', dict(
        base=dict(kz='101', last_pid='430001', offset='7', request_times='99'),
        serverState=state, requestCount=10)))
cases = []
for kind, name, inputs in scenarios:
    emulator = ReplyFollowupEmulator()
    result = emulator.run_followup(kind, inputs)
    cases.append(dict(kind=kind, name=name, input=inputs, expected=result))
    del emulator
    gc.collect()
output = dict(
    referenceExecutableSHA256=reference.REFERENCE_SHA256,
    methods=dict(floor='0x102f44cec', thread='0x102c8e7d8', load='0x102c8e620'),
    scope='Native parameter transformation and initial dispatch gating only. Prepared PB '
          'parameters and model state are synthetic; Foundation primitives are explicitly '
          'substituted. Native load dispatch is intercepted. Does not run the official app '
          'on Simulator, choose configuration, execute SDKs, send any network request, '
          'decode the follow-up response, update UI, or establish moderation outcome.',
    cases=cases)
if args.verify:
    assert json.loads(args.verify.read_text()) == output, 'Native follow-up fixture drift'
else:
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
print(f'PASS: native follow-up parameter and dispatch observations ({len(cases)})')
