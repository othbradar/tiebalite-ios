"""Replay default AF status validation and native parser metrics offline.

The accepted 22.11.1 singleton constructs BBAAFNetworkingRequestManager.
Its AFHTTPResponseSerializer default range is 200..<300, content types nil.
Only Foundation objects and diagnostics are substituted; native validation,
error construction, parser control flow execute. No network or SDK executes.
Alternate configured engines are outside this default-path fixture.
"""
import argparse
import json
import struct
from pathlib import Path
from emulate_http import HTTPEmulator
from emulate_reply import reg
from emulate_response import Item
from generate_parse_failure_metrics import ParseFailureEmulator
import read_macho as reference


class StatusEmulator(HTTPEmulator):
    def __init__(self):
        super().__init__()
        # Imported Foundation string constants, explicitly scoped to NSError
        # diagnostics. The native validator still builds and returns the error.
        for address, name in self.imports.items():
            if name.lstrip('_') in ['NSLocalizedDescriptionKey', 'NSURLErrorFailingURLErrorKey', 'NSUnderlyingErrorKey']:
                storage = self.box(('constant-storage', name))
                self.uc.mem_write(storage, struct.pack('<Q', self.box(name.lstrip('_'))))
                self.uc.mem_write(address, struct.pack('<Q', storage))

    def hook(self, uc, address, size, context):
        ins = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
        if ins.mnemonic in ['bl', 'b'] and ins.operands[0].imm == 0x104315540:
            # Execute AF's actual NSError-combining helper, not a substitute.
            if ins.mnemonic == 'bl':
                uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
            uc.reg_write(reg.UC_ARM64_REG_PC, 0x104315540)
            return
        super().hook(uc, address, size, context)

    def message(self, selector):
        obj = self.value(self.x(0))
        if selector == 'class':
            return self.x(0)
        if selector == 'isKindOfClass:' and isinstance(obj, Item):
            return int(self.value(self.x(2)) == ('class', 'NSHTTPURLResponse'))
        if selector == 'containsIndex:' and isinstance(obj, range):
            return int(self.x(2) in obj)
        if selector == 'mainBundle':
            return self.box(('instance', 'NSBundle'))
        if selector == 'localizedStringForKey:value:table:':
            return self.x(2)  # No localization I/O. Diagnostics do not decide validation.
        if selector == 'localizedStringForStatusCode:':
            return self.box('synthetic-status')
        if selector == 'stringWithFormat:':
            return self.box('synthetic-diagnostic')
        if selector == 'dictionaryWithObjects:forKeys:count:':
            return self.box({self.value(self.pointer(self.x(3) + n * 8)):
                             self.value(self.pointer(self.x(2) + n * 8)) for n in range(self.x(4))})
        if selector == 'setObject:forKeyedSubscript:':
            obj[self.value(self.x(3))] = self.value(self.x(2))
            return 0
        if selector == 'mutableCopy' and isinstance(obj, dict):
            return self.box(obj.copy())
        if selector == 'errorWithDomain:code:userInfo:':
            self.error_code = self.x(3)
            return self.box(Item(dict(domain=self.value(self.x(2)), code=self.x(3),
                                      userInfo=self.value(self.x(4)))))
        if isinstance(obj, Item) and selector in obj.fields:
            value = obj.fields[selector]
            return value if isinstance(value, int) else self.box(value)
        return super().message(selector)

    def validate(self, status):
        self.error_code = None
        serializer = Item(dict(acceptableContentTypes=None, acceptableStatusCodes=range(200, 300)))
        response = Item(dict(statusCode=status, URL='https://example.invalid/fixture', MIMEType='application/protobuf'))
        self.execute(0x104314e60, {0: serializer, 2: response, 3: b'fixture', 4: None})
        code = self.error_code
        if code is not None and code >= 2**63:
            code -= 2**64
        return dict(accepted=bool(self.x(0)), errorCode=code)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output must be new')
    statuses = [199, 200, 201, 204, 299, 300, 401, 429, 503]
    gates = [dict(statusCode=s, **StatusEmulator().validate(s)) for s in statuses]
    cases = []
    for gate in gates:
        for protobuf in [False, True]:
            for body_kind in ['success', 'rejected', 'empty']:
                code = 0 if body_kind != 'rejected' else 5
                raw = b'\x0a\x00' if protobuf else json.dumps(dict(error_code=code, logid=123)).encode()
                if body_kind == 'empty':
                    raw = b''
                decoded = dict(error=Item(dict(errorNum=str(code), errorMsg='', logid=None))) if protobuf else None
                sample = dict(api='/c/c/post/add' if protobuf else '/c/s/tbs', durationSeconds=.25,
                              uploadBytes=1800, downloadBytes=700)
                expected = ParseFailureEmulator(sample).run(raw, protobuf, decoded,
                    state=3 if gate['accepted'] else 4, error_code=gate['errorCode'], status_code=gate['statusCode'])
                cases.append(dict(name=f"http-{gate['statusCode']}-proto-{protobuf}-{body_kind}",
                    input=dict(sample, protobuf=protobuf, statusCode=gate['statusCode'], bodyKind=body_kind, errorCode=code),
                    expected=expected))
    args.output.write_text(json.dumps(dict(referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope=__doc__, statusValidation=gates, cases=cases), ensure_ascii=False, indent=2) + '\n')
    print('PASS: default AF validator', len(gates), 'native parser cases', len(cases))


if __name__ == '__main__':
    main()
