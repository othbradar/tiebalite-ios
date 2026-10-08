"""Bounded native signing with synthetic values; no SDK or account initialization.

Executes the native concatenation and MD5 formatting methods. Foundation objects
and the system CC_MD5 primitive have explicit offline substitutes.
"""
import hashlib
import struct

from emulate_reply import Emulator, reg
import read_macho as reference


class SigningEmulator(Emulator):
    def finish_call(self, address, instruction, result):
        next_pc = address + 4 if instruction.mnemonic == 'bl' else self.x(30)
        self.uc.reg_write(reg.UC_ARM64_REG_X0, result)
        if instruction.mnemonic == 'bl':
            self.uc.reg_write(reg.UC_ARM64_REG_LR, next_pc)
        self.uc.reg_write(reg.UC_ARM64_REG_PC, next_pc)

    def hook(self, uc, address, size, context):
        try:
            instruction = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
            if instruction.mnemonic in ['bl', 'b']:
                target = instruction.operands[0].imm
                symbol = self.runtime_symbol(target)
                selector = reference.selector_stub(target)
                native_methods = {'md5:': 0x1022bd39c, 'stokenFilter:': 0x1024b7610}
                if selector in native_methods:
                    uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
                    uc.reg_write(reg.UC_ARM64_REG_PC, native_methods[selector])
                    return
                if symbol == '_objc_alloc_init' and self.value(self.x(0)) == ('class', 'NSMutableString'):
                    self.finish_call(address, instruction, self.box(''))
                    return
                if symbol == '_objc_retainAutorelease':
                    self.finish_call(address, instruction, self.x(0))
                    return
                if symbol == '_CC_MD5':
                    digest = hashlib.md5(bytes(uc.mem_read(self.x(0), self.x(1)))).digest()
                    uc.mem_write(self.x(2), digest)
                    self.finish_call(address, instruction, self.x(2))
                    return
            super().hook(uc, address, size, context)
        except Exception as error:
            self.error = error
            uc.emu_stop()

    def message(self, selector):
        receiver = self.value(self.x(0))
        if selector == 'allKeys':
            return self.box(list(receiver))
        if selector == 'sortedArrayUsingComparator:':
            # All protocol keys in these fixtures are ASCII. Verify the actual
            # comparator block still requests NSString literal comparison.
            assert all(key.isascii() for key in receiver)
            comparator = reference.pointer(self.x(2) + 16)
            allowed = {reference.pointer(0x10c10c518 + 16), reference.pointer(0x10c10c4f8 + 16)}
            assert comparator in allowed
            return self.box(sorted(receiver))
        if selector == 'countByEnumeratingWithState:objects:count:':
            state, buffer, maximum = self.x(2), self.x(3), self.x(4)
            consumed = self.pointer(state)
            batch = receiver[consumed:consumed + maximum]
            self.uc.mem_write(state, struct.pack('<QQQ', consumed + len(batch), buffer, state + 40))
            if batch:
                self.uc.mem_write(buffer, b''.join(struct.pack('<Q', self.box(value)) for value in batch))
            return len(batch)
        if selector == 'objectForKeyedSubscript:':
            return self.box(receiver.get(self.value(self.x(2))))
        if selector == 'appendFormat:':
            assert self.value(self.x(2)) == '%@=%@'
            stack = self.uc.reg_read(reg.UC_ARM64_REG_SP)
            first, second = self.value(self.pointer(stack)), self.value(self.pointer(stack + 8))
            self.objects[self.x(0)] += first + '=' + second
            return 0
        if selector == 'appendString:':
            self.objects[self.x(0)] += self.value(self.x(2))
            return 0
        if selector == 'tiebaSignKey':
            # This exact constant already exists in the repository's open-source
            # protocol. It is not an SDK access key or a user's credential.
            value = reference.label(0x10c426aa0).removeprefix('CFString:')
            assert value == 'tiebaclient!!!'
            return self.box(value)
        if selector == 'dataUsingEncoding:':
            assert self.x(2) == 4
            return self.box(receiver.encode('utf-8'))
        if selector == 'bytes':
            address = self.box(('synthetic-bytes', len(receiver)))
            # A fixture digest input can exceed the normal object slot size.
            self.next_object += (len(receiver) + 4095) & ~4095
            self.uc.mem_write(address, receiver)
            return address
        if selector == 'stringWithFormat:':
            template = self.value(self.x(2))
            assert template == '%02X' * 16
            stack = self.uc.reg_read(reg.UC_ARM64_REG_SP)
            return self.box(''.join(f'{self.pointer(stack + 8 * index):02X}' for index in range(16)))
        return super().message(selector)

    def execute(self, address, value):
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('instance', 'TBCServerAPI')))
        self.uc.reg_write(reg.UC_ARM64_REG_X2, self.box(value))
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(address, self.end, count=100000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('instruction budget exceeded')
        return self.value(self.x(0))

    def signature(self, parameters):
        raw = self.execute(0x1024b4638, parameters)
        return self.execute(0x1022bd39c, raw)


class CommonSigningEmulator(SigningEmulator):
    """The native merge/sign/return block after runtime Common is populated.

The earlier device/account/SDK providers are deliberately outside this replay.
It starts at the real block boundary with explicit registers/stack locals and
stops before cleanup of the earlier frame's unrelated objects.
"""
    def hook(self, uc, address, size, context):
        if address == 0x1024b3458:
            uc.emu_stop()
            return
        super().hook(uc, address, size, context)

    def message(self, selector):
        if selector == 'dictionaryWithDictionary:':
            return self.box(dict(self.value(self.x(2))))
        if selector == 'reqParams':
            return self.box(self.business)
        if selector in ['stokenLeakFixSwitch', 'isHttpsRequest']:
            return 1  # Actual filter body must retain state for an HTTPS request.
        if selector == 'api':
            return self.box('c/c/post/add')
        if selector == 'needSig:':
            return int(self.additional_signature is not None)
        if selector == 'toString:':
            self.additional_signature_inputs.append(self.value(self.x(2)))
            return self.box(self.additional_signature)  # Explicit opaque provider substitute.
        if selector == 'generatePackageVersionString':
            return self.box(self.metadata['packageVersion'])
        if selector == 'hitExperimentTypeKey':
            return self.box(self.metadata['experimentHits'])
        if selector == 'noHitExperimentTypeKey':
            return self.box(self.metadata['experimentMisses'])
        if selector == 'stringWithFormat:' and self.value(self.x(2)) == '%@^%@':
            stack = self.uc.reg_read(reg.UC_ARM64_REG_SP)
            values = [self.value(self.pointer(stack + 8 * index)) for index in range(2)]
            return self.box('^'.join('(null)' if value is None else value for value in values))
        return super().message(selector)

    def prepare(self, common, business, metadata, additional_signature=None):
        self.business, self.metadata = business, metadata
        self.additional_signature = additional_signature
        self.additional_signature_inputs = []
        stack = 0x7000d0000
        self.uc.reg_write(reg.UC_ARM64_REG_SP, stack)
        self.uc.reg_write(reg.UC_ARM64_REG_X26, self.box(dict(common)))
        self.uc.mem_write(stack + 0x70, struct.pack('<Q', self.box(('instance', 'TBCServerAPI'))))
        self.uc.mem_write(stack + 0x7c, struct.pack('<I', 0))  # Proto common-only branch.
        self.uc.emu_start(0x1024b2f94, self.end, count=100000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != 0x1024b3458:
            raise RuntimeError('Native common block did not reach the return/cleanup boundary')
        return self.value(self.x(19))
