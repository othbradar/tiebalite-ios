"""Replay iOS JSON preparation metrics and ordinary request headers offline.

Synthetic input only. Execute the SHA-checked native parser and numberAtPath;
replace Foundation scalar operations, intercept logging and all network outlets.
"""
import argparse
import json
import re
import struct
from pathlib import Path
from generate_transfer_metrics import MetricsEmulator
from emulate_http import HTTPEmulator
from emulate_reply import reg
import read_macho as reference


class FormMetricsEmulator(MetricsEmulator):
    def hook(self, uc, address, size, context):
        ins = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
        if ins.mnemonic in ['bl', 'b'] and reference.selector_stub(ins.operands[0].imm) == 'numberAtPath:':
            if ins.mnemonic == 'bl':
                uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
            uc.reg_write(reg.UC_ARM64_REG_PC, 0x10265afdc)
            return
        super().hook(uc, address, size, context)

    def message(self, selector):
        obj = self.value(self.x(0))
        if selector == 'doubleValue' and isinstance(obj, str):
            match = re.match(r'\s*[+-]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?', obj)
            value = float(match[0]) if match else 0.0
            self.uc.reg_write(reg.UC_ARM64_REG_D0, struct.unpack('<Q', struct.pack('<d', value))[0])
            return 0
        if selector == 'numberWithDouble:':
            value = struct.unpack('<d', struct.pack('<Q', self.uc.reg_read(reg.UC_ARM64_REG_D0)))[0]
            return self.box(value)
        return super().message(selector)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output must be new')
    cases = []
    payloads = [
        ('login-success', '/c/s/login', {'error_code': 0, 'logid': 9007199254740993}),
        ('tbs-success', '/c/s/tbs', {'error_code': '0', 'logid': '9007199254740993', 'tbs': 'fixture'}),
        ('login-rejected', '/c/s/login', {'error_code': 5, 'logid': 1234}),
        ('negative-json-error', '/c/s/tbs', {'error_code': -7, 'logid': 1235}),
        ('nested-error', '/c/s/tbs', {'error_code': 0, 'error': {'errno': 6}, 'logid': 1236}),
        ('primary-error-wins', '/c/s/tbs', {'error_code': 5, 'error': {'errno': 6}}),
        ('missing-logid', '/c/s/login', {'error_code': '0'}),
        ('null-logid', '/c/s/login', {'error_code': 0, 'logid': None}),
        ('invalid-logid-type', '/c/s/tbs', {'error_code': 0, 'logid': ['invalid']}),
        ('decimal-logid', '/c/s/tbs', {'error_code': 0, 'logid': '123.75'}),
        ('nested-only-success', '/c/s/tbs', {'error': {'errno': 0}, 'logid': 8}),
        ('nonnumeric-logid', '/c/s/tbs', {'error_code': 0, 'logid': 'no-number'}),
    ]
    for name, api, payload in payloads:
        sample = dict(api=api, durationSeconds=.25, uploadBytes=1750, downloadBytes=650)
        emulator = FormMetricsEmulator(sample)
        raw = json.dumps(payload, separators=(',', ':'))
        emulator.run_json(raw.encode())
        expected = {k: emulator.stat.fields[k] for k in ['api', 'logid', 'cost', 'result', 'uploadBytes', 'downloadBytes']}
        if expected['result'] >= 2**63:
            expected['result'] -= 2**64
        cases.append(dict(name=name, input=dict(sample, responseJSON=raw), expected=expected))
    headers = [dict(clientLogID=value, expected=HTTPEmulator().headers(0, value, 'fixture-agent', {}))
               for value in [0, -1, 1000001, -2]]
    args.output.write_text(json.dumps(dict(referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Native JSON parser metrics and non-Proto header branch; synthetic data, no network.',
        cases=cases, headers=headers), ensure_ascii=False, indent=2) + '\n')
    print('PASS: native form metrics', len(cases), 'and headers', len(headers))


if __name__ == '__main__':
    main()
