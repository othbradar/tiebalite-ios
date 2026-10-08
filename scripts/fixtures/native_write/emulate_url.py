"""Replay only the native short-connection URL block, with synthetic inputs.

No native app entry point, network transport or credentials are used. The
reference executable is SHA-checked by read_macho before any instruction runs.
"""
import json
from emulate_reply import Emulator, reg
import read_macho as reference


class URLEmulator(Emulator):
    def hook(self, uc, address, size, context):
        if address == 0x100249168:
            self.result = dict(address=self.value(self.x(20)), command=self.command)
            uc.emu_stop()
            return
        super().hook(uc, address, size, context)

    def message(self, selector):
        if selector == 'address':
            return self.box(self.inputs['address'])
        if selector == 'messageRequestType':
            return self.inputs['requestType']
        if selector == 'shortAsLongConnection':
            return int(self.inputs['shortAsLong'])
        if selector == 'serverApi':
            return self.server
        if selector == 'setRequestCMD:':
            self.command = self.x(2)
            return 0
        if selector == 'requestCMD':
            return self.command
        if selector == 'rangeOfString:':
            text, needle = self.value(self.x(0)), self.value(self.x(2))
            index = text.find(needle)
            self.uc.reg_write(reg.UC_ARM64_REG_X1, len(needle) if index >= 0 else 0)
            return index if index >= 0 else (1 << 63) - 1
        if selector == 'stringWithFormat:':
            template = self.value(self.x(2))
            if template in ['?cmd=%ld', '&cmd=%ld']:
                value = self.pointer(self.uc.reg_read(reg.UC_ARM64_REG_SP))
                return self.box(template.replace('%ld', str(value)))
        return super().message(selector)

    def execute(self, address, command, request_type=3, short_as_long=False):
        self.inputs = dict(address=address, requestType=request_type, shortAsLong=short_as_long)
        self.command, self.result, self.error = 0, None, None
        self.server = self.box(('instance', 'TBCServerAPI'))
        self.uc.reg_write(reg.UC_ARM64_REG_X19, self.box(('instance', 'TBCBaseModel')))
        self.uc.reg_write(reg.UC_ARM64_REG_X22, command)
        self.uc.reg_write(reg.UC_ARM64_REG_X26, 0x10e43d000)
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(0x100249044, self.end, count=1000)
        if self.error:
            raise self.error
        if self.result is None:
            raise RuntimeError('Native URL block did not reach its boundary')
        return dict(input=self.inputs | dict(command=command), output=self.result)


if __name__ == '__main__':
    emulator = URLEmulator()
    cases = [
        emulator.execute('/c/c/post/add', 309731),
        emulator.execute('c/c/thread/add', 309730),
        emulator.execute('/fixture?existing=1', 309731),
        emulator.execute('/fixture', 309731, request_type=1, short_as_long=True),
        emulator.execute('/fixture', 309731, request_type=1),
        emulator.execute('/fixture', 0, request_type=1, short_as_long=True),
    ]
    print(json.dumps(dict(referenceSHA256=reference.REFERENCE_SHA256,
                         method='TBCBaseModel.loadInnerWithShotConnection',
                         block=['0x100249044', '0x100249168'], cases=cases), indent=2))
