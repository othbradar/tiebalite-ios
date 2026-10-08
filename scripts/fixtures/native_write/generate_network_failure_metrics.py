"""Replay native failure/completed-HTTP parser branches with synthetic inputs.

Transport state is explicit input: this does not emulate the BBA HTTP library,
SDKs, network, retries or credentials. Byte counters start at their consumed
zero state, matching the next-request lifecycle. Cancellation is evidence only;
the app deliberately suppresses cancelled/old-account metric publication.
"""
import argparse
import json
from pathlib import Path
from emulate_response import Item
from generate_parse_failure_metrics import ParseFailureEmulator
import read_macho as reference


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output must be new')
    cases = []
    for state, code in [(4, -1001), (4, -1009), (4, -1005), (4, -1200), (4, None), (5, -999)]:
        sample = dict(api='/c/c/post/add', durationSeconds=.25, uploadBytes=1800, downloadBytes=700)
        expected = ParseFailureEmulator(sample).run(b'', True, None, state=state, error_code=code)
        cases.append(dict(name=f'state-{state}-error-{code}', input=dict(sample, state=state, errorCode=code), expected=expected))
    for protobuf in [False, True]:
        for status in [201, 503]:
            for valid in [False, True]:
                sample = dict(api='/c/c/post/add' if protobuf else '/c/s/tbs',
                              durationSeconds=.25, uploadBytes=1800, downloadBytes=700)
                raw = b'\x0a\x00' if protobuf else b'{"error_code":0}'
                decoded = dict(error=Item(dict(errorNum='0', errorMsg='', logid=None))) if protobuf else None
                expected = ParseFailureEmulator(sample).run(raw if valid else b'', protobuf, decoded, status_code=status)
                cases.append(dict(name=f'http-{status}-proto-{protobuf}-valid-{valid}',
                    input=dict(sample, state=3, statusCode=status, protobuf=protobuf, valid=valid), expected=expected))
    args.output.write_text(json.dumps(dict(referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope=__doc__, cases=cases), ensure_ascii=False, indent=2) + '\n')
    print('PASS: native network failure / HTTP parser cases', len(cases))


if __name__ == '__main__':
    main()
