"""Bounded native TBS JSON parsing/completion and ordinary-form signing.

Foundation JSON/string primitives use synthetic substitutes. Database writes,
notifications and network are intercepted; no actual account or SDK is used.
"""
import json
import re
import struct
from emulate_common_transform import CommonTransformEmulator
from emulate_response import ResponseEmulator, Item
from emulate_reply import reg
import read_macho as reference


class TBSCommonEmulator(CommonTransformEmulator):
    def hook(self, uc, address, size, context):
        try:
            ins = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
            if ins.mnemonic in ['bl', 'b']:
                selector = reference.selector_stub(ins.operands[0].imm)
                methods = {'urlIsSupportLegal:': 0x1024b0dc8, 'urlArray': 0x1024b1004,
                           'needSig:': 0x1024f0720}
                if selector in methods:
                    if ins.mnemonic == 'bl':
                        uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
                    uc.reg_write(reg.UC_ARM64_REG_PC, methods[selector])
                    return
            super().hook(uc, address, size, context)
        except Exception as error:
            self.error = error
            uc.emu_stop()

    def message(self, selector):
        obj = self.value(self.x(0))
        if selector == 'objectForKey:':
            return self.box(obj.get(self.value(self.x(2))))
        if selector == 'arrayWithObjects:count:':
            return self.box([self.value(self.pointer(self.x(2) + i * 8)) for i in range(self.x(3))])
        if selector == 'dictionaryWithObjects:forKeys:count:':
            return self.box({self.value(self.pointer(self.x(3) + i * 8)):
                             self.value(self.pointer(self.x(2) + i * 8)) for i in range(self.x(4))})
        if selector == 'rangeOfString:':
            needle = self.value(self.x(2))
            index = obj.find(needle)
            self.uc.reg_write(reg.UC_ARM64_REG_X1, len(needle) if index >= 0 else 0)
            return index if index >= 0 else 0x7fffffffffffffff
        return super().message(selector)

    def run_form(self, context, static, business, metrics):
        assert context['api'] == '/c/s/tbs'
        self.metadata = {}
        self.additional_signature = None
        self.additional_signature_inputs = []
        self.signed = None
        result = self.run_dynamic(context, static, business, metrics, include_request_params=True)
        if self.signed is None:
            raise RuntimeError('missing native signed form return')
        result['signedForm'] = self.signed
        return result


class TBSResponseEmulator(ResponseEmulator):
    def hook(self, uc, address, size, context):
        try:
            ins = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
            if ins.mnemonic in ['bl', 'b']:
                target = ins.operands[0].imm
                if reference.selector_stub(target) == 'stringAtPath:':
                    if ins.mnemonic == 'bl':
                        uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
                    uc.reg_write(reg.UC_ARM64_REG_PC, 0x10265b16c)
                    return
                if self.runtime_symbol(target) == '_objc_loadWeakRetained':
                    uc.reg_write(reg.UC_ARM64_REG_X0, self.pointer(self.x(0)))
                    uc.reg_write(reg.UC_ARM64_REG_PC, address + 4 if ins.mnemonic == 'bl' else self.x(30))
                    return
            super().hook(uc, address, size, context)
        except Exception as error:
            self.error = error
            uc.emu_stop()

    @staticmethod
    def is_kind(value, cls):
        if cls == ('class', 'NSNumber'):
            return int(isinstance(value, (int, float)))
        return ResponseEmulator.is_kind(value, cls)

    def message(self, selector):
        obj = self.value(self.x(0))
        if obj is None:
            return 0
        if selector == 'UTF8String' and isinstance(obj, bytes):
            try:
                return self.box(obj.decode('utf-8'))
            except UnicodeDecodeError:
                return 0
        if selector == 'JSONValue':
            try:
                return self.box(json.loads(obj))
            except ValueError:
                return 0
        if selector == 'dictionaryWithObjectsAndKeys:':
            values = [self.x(2)]
            stack = self.uc.reg_read(reg.UC_ARM64_REG_SP)
            for index in range(20):
                value = self.pointer(stack + index * 8)
                if not value:
                    break
                values.append(value)
            else:
                raise RuntimeError('unterminated synthetic varargs')
            assert len(values) % 2 == 0
            return self.box({self.value(values[i + 1]): self.value(values[i]) for i in range(0, len(values), 2)})
        if selector == 'objectAtPath:':
            # Exact simple dictionary paths used by this parser/completion.
            for key in self.value(self.x(2)).split('/'):
                if key:
                    obj = obj.get(key) if isinstance(obj, dict) else None
            return self.box(obj)
        if selector == 'intValue':
            match = re.match(r'\s*([+-]?[0-9]+)', obj)
            value = int(match[1]) if match else 0
            assert -(2**31) <= value < 2**31  # Fixture excludes ambiguous overflow.
            return value & 0xffffffff
        if selector == 'stringWithFormat:' and self.value(self.x(2)) == '%lld':
            value = self.pointer(self.uc.reg_read(reg.UC_ARM64_REG_SP))
            return self.box(str(value if value < 2**63 else value - 2**64))
        if selector == 'setTbsProtectLock:':
            self.lock_values.append(self.x(2))
            return 0
        if selector == 'saveTbsToLogin:tbs:':
            self.saved.append(dict(userID=self.value(self.x(2)), value=self.value(self.x(3))))
            return 0
        if selector == 'defaultCenter':
            return self.box(('instance', 'FixtureNotificationCenter'))
        if selector == 'postNotificationName:object:':
            assert self.value(self.x(2)) == 'kTBCFetchTbsInfoSuccessNotification'
            self.notifications += 1
            return 0
        return super().message(selector)

    def run_json(self, raw):
        self.log_count, self.decode_count, self.log_formats = 0, 0, []
        self.lock_values, self.saved, self.notifications = [], [], 0
        self.api = Item(dict(api='/c/s/tbs', netCost=0, state=3, rawData=raw,
                             requestCMD=0, useProto=0, logid=None, parsedData=None, error=None,
                             request=Item(dict(transactionMetric=Item(dict(domainLookupDuration=0, connectDuration=0,
                             totalReadAndWriteDuration=0, requestBytes=1, responseBytes=len(raw),
                             response=Item(dict(statusCode=200))))))))
        stat = Item(dict(logid=0, result=0))
        self.uc.mem_write(0x10ebbfe78, struct.pack('<Q', self.box(stat)))
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(self.api))
        self.uc.reg_write(reg.UC_ARM64_REG_X2, 0)
        self.execute_method(0x1024b5db0)
        block = self.box(('fixture-block', 'TBS-completion'))
        self.uc.mem_write(block + 0x20, struct.pack('<QQ', self.box('42'), self.box(('instance', 'FixtureSettings'))))
        self.uc.reg_write(reg.UC_ARM64_REG_X0, block)
        self.uc.reg_write(reg.UC_ARM64_REG_X1, self.box(self.api))
        self.execute_method(0x101c26318)
        return dict(state=self.api.fields['state'], hasError=self.api.fields['error'] is not None,
                    saved=self.saved, lockValues=self.lock_values, notifications=self.notifications)
