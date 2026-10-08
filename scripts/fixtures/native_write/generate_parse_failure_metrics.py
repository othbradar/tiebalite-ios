"""Replay native response-parser statistics with synthetic failed responses.

Executes the SHA-checked ARM64 parser, with explicit Foundation/IDL substitutes.
No requests, account data, SDK initialization, telemetry or retries execute.
The IDL result is an input, not a claim about arbitrary wire decoder behavior.
"""
import argparse
import json
import struct
from pathlib import Path
from emulate_response import Item
from emulate_reply import reg
from generate_form_metrics import FormMetricsEmulator
import read_macho as reference


class ParseFailureEmulator(FormMetricsEmulator):
    def message(self, selector):
        if (selector == 'getMaxAlertCount:defaultValue:'
                and self.value(self.x(0)) == ('instance', 'TBCNewStatisticLogService')):
            return 0  # Suppress the optional debug alert; parser decisions still execute.
        if (selector == 'logAlertType:alertMsg:'
                and self.value(self.x(0)) == ('instance', 'TBCNewStatisticLogService')):
            self.log_count += 1  # Explicit telemetry sink, no host logging or network.
            return 0
        return super().message(selector)

    def hook(self, uc, address, size, context):
        ins = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
        if ins.mnemonic in ['bl', 'b'] and ins.operands[0].imm == 0x1002699a0:
            # Native debug assertion/reporting sink, not a parser decision.
            self.log_count += 1
            uc.reg_write(reg.UC_ARM64_REG_PC, address + 4 if ins.mnemonic == 'bl' else self.x(30))
            return
        super().hook(uc, address, size, context)

    def run(self, raw, protobuf, decoded, state=3, error_code=None, status_code=200):
        self.log_count, self.decode_count, self.log_formats = 0, 0, []
        self.decoded = decoded
        self.api = Item(dict(api=self.sample['api'], netCost=0, state=state, rawData=raw,
            requestCMD=309731 if protobuf else 0, useProto=int(protobuf),
            logid=None, parsedData=None, error=None,
            request=Item(dict(error=Item(dict(code=error_code)) if error_code is not None else None,
                transactionMetric=Item(dict(domainLookupDuration=0, connectDuration=0,
                totalReadAndWriteDuration=0, requestBytes=0, responseBytes=0,
                response=Item(dict(statusCode=status_code))))))))
        stat = Item(dict(logid=0, result=0, uploadBytes=0, downloadBytes=0))
        self.uc.mem_write(0x10ebbfe78, struct.pack('<Q', self.box(stat)))
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(self.api))
        self.uc.reg_write(reg.UC_ARM64_REG_X2, int(protobuf))
        self.execute_method(0x1024b5db0)
        result = {k: stat.fields[k] for k in ['api', 'logid', 'cost', 'result', 'uploadBytes', 'downloadBytes']}
        if result['result'] >= 2**63:
            result['result'] -= 2**64
        return dict(metrics=result, state=self.api.fields['state'], decodeCount=self.decode_count)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output must be new')
    cases = []
    values = [
        ('protobuf-empty', True, b'', None),
        ('protobuf-decode-nil', True, bytes([255]), None),
        ('protobuf-missing-data', True, bytes([10, 0]),
            dict(error=Item(dict(errorNum='0', errorMsg='', logid=None)))),
        ('protobuf-rejected-missing-data', True, bytes([10, 2, 8, 5]),
            dict(error=Item(dict(errorNum='5', errorMsg='fixture', logid=None)))),
        ('json-empty', False, b'', None),
        ('json-invalid-utf8', False, bytes([255]), None),
        ('json-invalid', False, b'{', None),
        ('json-array', False, b'[]', None),
        ('json-missing-code', False, b'{"logid":999}', None),
        ('json-null-code', False, b'{"error_code":null,"error":{"errno":[]},"logid":999}', None),
    ]
    for name, protobuf, raw, decoded in values:
        sample = dict(api='/c/c/post/add' if protobuf else '/c/s/tbs', durationSeconds=.25,
                      uploadBytes=1800, downloadBytes=700)
        expected = ParseFailureEmulator(sample).run(raw, protobuf, decoded)
        cases.append(dict(name=name, input=dict(sample, protobuf=protobuf, rawHex=raw.hex()), expected=expected))
    args.output.write_text(json.dumps(dict(referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Native parser with successful transport; IDL output and Foundation are explicit synthetic inputs.',
        cases=cases), ensure_ascii=False, indent=2) + '\n')
    print('PASS: native parser failure metrics', len(cases))


if __name__ == '__main__':
    main()
