"""Reproduce the synthetic native reply-compose text preparation fixture."""
import argparse
import gc
import json
import os
from pathlib import Path
import subprocess
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
from emulate_reply_content import ReplyContentEmulator  # noqa: E402

base = dict(supportsServerText=True, serverText='  Synthetic reply\n#(face) 😀  ',
            visibleText='visible fallback', isFloor=False, recipientPrompt=None,
            portrait='fixture-portrait', displayName='Fixture recipient')
scenarios = [
    ('thread-preserves-server-text', {}),
    ('floor-without-recipient-prompt', dict(isFloor=True)),
    ('recipient-prefix', dict(isFloor=True, recipientPrompt='回复 Fixture recipient :')),
    ('thread-ignores-recipient-prompt', dict(recipientPrompt='回复 Fixture recipient :')),
    ('empty-server-falls-back', dict(serverText='')),
    ('nil-server-falls-back', dict(serverText=None)),
    ('unsupported-server-selector-falls-back', dict(supportsServerText=False)),
    ('no-text-is-empty', dict(serverText=None, visibleText=None)),
    ('empty-prompt-no-prefix', dict(isFloor=True, recipientPrompt='')),
    ('fullwidth-colon-foundation-match', dict(isFloor=True, recipientPrompt='回复 Fixture recipient ：')),
    ('missing-space-not-matching', dict(isFloor=True, recipientPrompt='回复 Fixture recipient:')),
    ('prompt-must-match-entire-string', dict(isFloor=True, recipientPrompt='prefix 回复 Fixture recipient :')),
    ('multiline-name', dict(isFloor=True, recipientPrompt='回复 Fixture\nrecipient :', displayName='Fixture\nrecipient')),
    ('missing-recipient-values', dict(isFloor=True, recipientPrompt='回复 Fixture recipient :', portrait=None, displayName=None)),
    ('whitespace-server-is-not-empty', dict(serverText='\n ')),
    ('long-compose-not-legacy-truncated', dict(isFloor=True, serverText='文' * 141 + '#(face)')),
]
prompts = [dict(base, **changes)['recipientPrompt'] for _, changes in scenarios]
foundation = subprocess.run(
    ['xcrun', 'swift', str(Path(__file__).with_name('foundation_reply_predicate.swift'))],
    input=json.dumps(prompts), text=True, capture_output=True, check=True)
matches = json.loads(foundation.stdout)
assert len(matches) == len(scenarios) and all(isinstance(value, bool) for value in matches)
cases = []
for (name, changes), matched in zip(scenarios, matches):
    inputs = dict(base, **changes)
    emulator = ReplyContentEmulator()
    result = emulator.run_content(inputs, matched)
    cases.append(dict(name=name, input=inputs, foundationPredicateMatch=matched, expected=result))
    del emulator
    gc.collect()
output = dict(referenceExecutableSHA256=reference.REFERENCE_SHA256,
              method='TBCReplyComposeSubmitPlugin.generatePbReplyContent', address='0x1023deab0',
              scope='First explicit submission on the native reply-compose plugin path. Executes the '
                    'native content method; editor prepared text is synthetic. The predicate primitive '
                    'uses host Apple Foundation (including width folding), with parity checked on iOS '
                    'Simulator. Remaining Foundation primitives are closed substitutes. '
                    'Does not select the runtime experiment branch, convert rich attachments, execute '
                    'verification replay, upload, send, or prove server moderation.', cases=cases)
if args.verify:
    assert json.loads(args.verify.read_text()) == output, 'Native reply-compose content fixture drift'
else:
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
print(f'PASS: native reply-compose text preparation ({len(cases)})')
