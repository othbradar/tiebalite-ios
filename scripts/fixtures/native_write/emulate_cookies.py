"""Replay native request-cookie selection with synthetic config, never a cookie jar."""
import struct

from emulate_reply import Emulator, reg
import read_macho as reference


class CookieEmulator(Emulator):
    def __init__(self):
        super().__init__()
        # Foundation exported NSString constants, represented only inside Unicorn.
        for slot, name in self.imports.items():
            if name.lstrip('_').startswith('NSHTTPCookie'):
                key = name.lstrip('_').removeprefix('NSHTTPCookie')
                storage = self.box(('foundation-export', key))
                self.uc.mem_write(storage, struct.pack('<Q', self.box(key)))
                self.uc.mem_write(slot, struct.pack('<Q', storage))

    def hook(self, uc, address, size, context):
        try:
            instruction = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
            if instruction.mnemonic in ['bl', 'b']:
                target = instruction.operands[0].imm
                selector = reference.selector_stub(target)
                if self.runtime_symbol(target) == '_objc_alloc_init':
                    assert self.value(self.x(0)) == ('class', 'NSMutableArray')
                    uc.reg_write(reg.UC_ARM64_REG_X0, self.box([]))
                    uc.reg_write(reg.UC_ARM64_REG_PC, address + 4)
                    return
                implementations = {'shouldKeepAlive': 0x10025de04, 'shouldGoSmallFlow': 0x10025df50}
                if selector in implementations:
                    uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
                    uc.reg_write(reg.UC_ARM64_REG_PC, implementations[selector])
                    return
            super().hook(uc, address, size, context)
        except Exception as error:
            self.error = error
            uc.emu_stop()

    def message(self, selector):
        receiver = self.value(self.x(0))
        if receiver is None:
            return 0
        scalars = {'netStatus': 'networkStatus', 'keepAliveWifi': 'wifiKeepAlive',
                   'keepAliveNonWifi': 'cellularKeepAlive', 'isGoSmallFlowStrategy': 'smallFlow'}
        if selector in scalars:
            return int(self.input[scalars[selector]])
        if selector == 'pubEnvValue':
            return self.box(self.input['smallFlowValue'])
        if selector == 'isEnableBDHttpDns':
            return 0  # Native hostname path: no IP rewriting or global-cookie lookup.
        if selector == 'syncData':
            return self.box(('instance', 'FixtureSyncData'))
        if selector == 'date':
            return self.box(('synthetic-date', 0))
        if selector == 'dateByAddingTimeInterval:':
            seconds = struct.unpack('<d', struct.pack('<Q', self.uc.reg_read(reg.UC_ARM64_REG_D0)))[0]
            return self.box(('synthetic-date', seconds))
        if selector == 'dictionaryWithObjectsAndKeys:':
            value = self.value(self.x(2))
            stack, offset, result = self.uc.reg_read(reg.UC_ARM64_REG_SP), 0, {}
            while value is not None:
                key = self.value(self.pointer(stack + offset))
                result[key] = value
                value = self.value(self.pointer(stack + offset + 8))
                offset += 16
            return self.box(result)
        if selector == 'cookieWithProperties:':
            properties = self.value(self.x(2))
            assert properties['Domain'] == '.baidu.com' and properties['Path'] == '/'
            # Foundation is a declared boundary; retain only request-relevant
            # fields, not an actual cookie or account identifier.
            if 'Name' not in properties or 'Value' not in properties:
                return 0
            return self.box({'name': properties['Name'], 'value': properties['Value']})
        if selector == 'safeAddObject:':
            value = self.value(self.x(2))
            if value is not None:
                receiver.append(value)
            return 0
        return super().message(selector)

    def run(self, inputs):
        self.input = inputs
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('instance', 'TBCServerAPI')))
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(0x10025d9ec, self.end, count=30000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('instruction budget exceeded')
        return self.value(self.x(0))
