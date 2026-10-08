"""Replay native IDPCache memory/disk dispatch with synthetic storage only.

Executes the original policy branches, saveInner type dispatch and memory-key
transform. Filesystem, clock and performance logging are explicit test doubles.
No official account data, network or host Objective-C code is accessed.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from emulate_reply import Emulator, reg
import read_macho as reference


class CacheEmulator(Emulator):
    def __init__(self, policy):
        super().__init__()
        self.policy = policy
        self.memory = {}
        self.disk = {}
        self.events = []

    def hook(self, uc, address, size, context):
        instruction = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
        if instruction.mnemonic in ['bl', 'b']:
            target = instruction.operands[0].imm
            selector = reference.selector_stub(target)
            helpers = {'saveInner:forKey:': 0x102bac0ac, 'memoryKey:withStoragePolicy:': 0x102baceac}
            if selector in helpers:
                if instruction.mnemonic == 'bl':
                    uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
                uc.reg_write(reg.UC_ARM64_REG_PC, helpers[selector])
                return
            if self.runtime_symbol(target) == '_CFAbsoluteTimeGetCurrent':
                uc.reg_write(reg.UC_ARM64_REG_D0, 0)
                uc.reg_write(reg.UC_ARM64_REG_PC, address + 4)
                return
        super().hook(uc, address, size, context)

    def message(self, selector):
        obj = self.value(self.x(0))
        if obj is None:
            return 0
        if selector == 'MD5':
            return self.box(hashlib.md5(obj.encode()).hexdigest())
        if selector == 'cacheStoragePolicy':
            return self.policy
        if selector in ['memoryCache', 'fileStorageEngine']:
            return self.box(('storage', selector))
        if selector == 'nameSpace':
            return self.box('default_cache')
        if selector in ['saveObject:forKey:', 'saveString:forKey:completionHandle:']:
            value, key = self.value(self.x(2)), self.value(self.x(3))
            disk = selector.startswith('saveString')
            (self.disk if disk else self.memory)[key] = value
            self.events.append('write-disk' if disk else 'write-memory')
            return 0
        if selector in ['loadObjectForKey:', 'objectForKey:error:']:
            disk = selector == 'objectForKey:error:'
            self.events.append('read-disk' if disk else 'read-memory')
            return self.box((self.disk if disk else self.memory).get(self.value(self.x(2))))
        if selector == 'stringWithFormat:':
            # Only key/diagnostic formatting. No production request bytes here.
            fmt = self.value(self.x(2))
            stack = self.uc.reg_read(reg.UC_ARM64_REG_SP)
            if fmt == '%@_%d':
                return self.box(f'{self.value(self.pointer(stack))}_{self.pointer(stack + 8)}')
            if fmt == '%@, %@, %d':
                return self.box('fixture-performance-info')
        if selector == 'uploadPerformanceTime:step:info:':
            return 0
        return super().message(selector)

    def run(self, address, value=None):
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('fixture', 'cache')))
        self.uc.reg_write(reg.UC_ARM64_REG_X2, self.box(value if address == 0x102babd68 else 'svcp_stk'))
        self.uc.reg_write(reg.UC_ARM64_REG_X3, self.box('svcp_stk') if address == 0x102babd68 else 0)
        self.uc.emu_start(address, self.end, count=10000)
        if self.error:
            raise self.error
        assert self.uc.reg_read(reg.UC_ARM64_REG_PC) == self.end
        return self.value(self.x(0)) if address == 0x102bac2c0 else None


class ExpiryEmulator(Emulator):
    def __init__(self, written, now):
        super().__init__()
        self.written = written
        self.now = now
        self.removed = False
        key = self.box('NSFileModificationDate')
        slot = self.box(('constant', 'NSFileModificationDate'))
        self.uc.mem_write(slot, struct.pack('<Q', key))
        self.uc.mem_write(0x10c081c40, struct.pack('<Q', slot))

    def hook(self, uc, address, size, context):
        instruction = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
        if instruction.mnemonic == 'bl' and instruction.operands[0].imm == 0x10026967c:
            uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('fixture', 'fileManager')))
            uc.reg_write(reg.UC_ARM64_REG_PC, address + 4)
            return
        super().hook(uc, address, size, context)

    def message(self, selector):
        obj = self.value(self.x(0))
        if selector == 'attributesOfItemAtPath:error:':
            return self.box({'NSFileModificationDate': self.written})
        if selector == 'objectAtPath:':
            return self.box(obj[self.value(self.x(2))])
        if selector in ['timeIntervalSince1970', 'doubleValue']:
            self.uc.reg_write(reg.UC_ARM64_REG_D0, struct.unpack('<Q', struct.pack('<d', float(obj)))[0])
            return 0
        if selector == 'removeItemAtPath:error:':
            self.removed = True
            return 1
        return super().message(selector)

    def run(self):
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('fixture', 'cache')))
        for index, value in [(2, 'fixture-path'), (3, 'fixture-key'), (4, 3600)]:
            self.uc.reg_write(getattr(reg, 'UC_ARM64_REG_X' + str(index)), self.box(value))
        self.uc.reg_write(reg.UC_ARM64_REG_X5, 0)
        self.uc.reg_write(reg.UC_ARM64_REG_D0, struct.unpack('<Q', struct.pack('<d', float(self.now)))[0])
        self.uc.emu_start(0x102bb1dd8, self.end, count=10000)
        if self.error:
            raise self.error
        assert self.uc.reg_read(reg.UC_ARM64_REG_PC) == self.end
        return self.removed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output must be new')
    cases = []
    for policy in [0, 1, 2]:
        emulator = CacheEmulator(policy)
        emulator.run(0x102babd68, 'fixture-state')
        first = emulator.run(0x102bac2c0)
        emulator.memory.clear()  # Process restart / loss of the memory cache.
        restarted = emulator.run(0x102bac2c0)
        cases.append(dict(storagePolicy=policy, beforeRestart=first, afterRestart=restarted, events=emulator.events))
    expiry = [dict(ageSeconds=age, removed=ExpiryEmulator(1000000, 1000000 + age).run())
              for age in [-1, 0, 3599, 3600, 3601]]
    args.output.write_text(json.dumps(dict(referenceExecutableSHA256=reference.REFERENCE_SHA256,
        sharedCachePolicy=2, scope='Native dispatch, synthetic memory/disk adapters; no real persistence.',
        cases=cases, expiry=expiry), indent=2) + '\n')
    print('PASS: native cache policies', len(cases))


if __name__ == '__main__':
    main()
