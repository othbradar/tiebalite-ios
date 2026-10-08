"""Native header/file-part branches with synthetic providers and no HTTP outlet."""
from emulate_reply import Emulator, reg
import read_macho as reference


class HTTPEmulator(Emulator):
    def hook(self, uc, address, size, context):
        # AFNetworking uses ordinary objc_msgSend rather than selector stubs.
        instruction = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
        if instruction.mnemonic in ['bl', 'b']:
            target = instruction.operands[0].imm
            if self.runtime_symbol(target) == '_objc_msgSend':
                try:
                    result = self.message(reference.string(self.x(1)))
                    next_pc = address + 4 if instruction.mnemonic == 'bl' else self.x(30)
                    uc.reg_write(reg.UC_ARM64_REG_X0, result)
                    if instruction.mnemonic == 'bl':
                        uc.reg_write(reg.UC_ARM64_REG_LR, next_pc)
                    uc.reg_write(reg.UC_ARM64_REG_PC, next_pc)
                except Exception as error:
                    self.error = error
                    uc.emu_stop()
                return
        super().hook(uc, address, size, context)

    def message(self, selector):
        if selector == 'dictionary':
            return self.box({})
        if selector in ['requestCMD', 'clientLogID']:
            return self.inputs[selector] & ((1 << 64) - 1)
        if selector in ['userAgent', 'customHeaders']:
            return self.box(self.inputs[selector])
        if selector == 'setValue:forKey:':
            self.value(self.x(0))[self.value(self.x(3))] = self.value(self.x(2))
            return 0
        if selector == 'stringWithFormat:':
            template = self.value(self.x(2))
            stack = self.uc.reg_read(reg.UC_ARM64_REG_SP)
            first = self.pointer(stack)
            if template == '%lld':
                return self.box(str(first if first < 1 << 63 else first - (1 << 64)))
            if template == 'form-data; name="%@"; filename="%@"':
                second = self.pointer(stack + 8)
                return self.box(template.replace('%@', self.value(first), 1).replace('%@', self.value(second), 1))
        if selector == 'appendPartWithHeaders:body:':
            self.part = dict(headers=self.value(self.x(2)), body=self.value(self.x(3)))
            return 0
        return super().message(selector)

    def execute(self, address, arguments):
        for index, value in arguments.items():
            self.uc.reg_write(getattr(reg, 'UC_ARM64_REG_X' + str(index)), self.box(value))
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(address, self.end, count=30000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('instruction budget exceeded')

    def headers(self, command, log_id, user_agent, custom_headers):
        self.inputs = dict(requestCMD=command, clientLogID=log_id,
                           userAgent=user_agent, customHeaders=custom_headers)
        self.execute(0x10025d3ec, {0: ('instance', 'TBCServerAPI')})
        return self.value(self.x(0))

    def file_part(self, data):
        self.part = None
        self.execute(0x104311458, {0: ('instance', 'AFStreamingMultipartFormData'),
                                 2: data, 3: 'data', 4: 'data', 5: 'image/jpeg'})
        if self.part is None:
            raise AssertionError('Native file-part method did not append a part')
        return self.part
