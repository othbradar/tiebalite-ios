"""Offline ARM64 business-method execution with explicit synthetic Objective-C inputs.

No host ObjC code, files, sockets, credentials, or native app entry point is invoked.
Unimplemented calls stop execution instead of silently returning a guessed value.
"""
import struct
import unicorn
from unicorn import arm64_const as reg
import read_macho as m


class Emulator:
    def __init__(self):
        self.uc = unicorn.Uc(unicorn.UC_ARCH_ARM64, unicorn.UC_MODE_ARM)
        self.objects = {}
        self.next_object = 0x500000000
        self.calls = []
        self.params = None
        self.loads = 0
        self.end = 0x600000000
        self.imports = {}
        self.singletons = {}
        self.error = None
        load_offset = 32
        virtual_sizes = {}
        for _ in range(struct.unpack_from('<I', m.data, 16)[0]):
            cmd, size = struct.unpack_from('<II', m.data, load_offset)
            if cmd == 0x19:
                base, size_vm = struct.unpack_from('<QQ', m.data, load_offset + 24)
                virtual_sizes[base] = size_vm
            load_offset += size
        for base, length, offset in m.segments:
            if not length:
                continue
            self.uc.mem_map(base & ~4095, (virtual_sizes[base] + (base & 4095) + 4095) & ~4095)
            self.uc.mem_write(base, m.data[offset:offset + length])
        self.uc.mem_map(0x500000000, 0x100000)
        self.uc.mem_map(0x600000000, 0x1000)
        self.uc.mem_map(0x700000000, 0x100000)
        for r in m.relocations:
            name = r.get('name', '')
            addr = r.get('vaddr', 0)
            if m.in_section(addr, '__objc_classrefs') and name:
                self.uc.mem_write(addr, struct.pack('<Q', self.box(('class', name))))
            if name.lstrip('_') == 'stack_chk_guard':
                self.uc.mem_write(addr, struct.pack('<Q', self.box(0)))
            if name:
                self.imports[addr] = name
        self.uc.hook_add(unicorn.UC_HOOK_CODE, self.hook)
        self.uc.hook_add(unicorn.UC_HOOK_MEM_INVALID, self.invalid_memory)

    def invalid_memory(self, uc, access, addr, size, value, _):
        self.error = RuntimeError('unmapped emulated memory ' + hex(addr) + ' at ' + hex(uc.reg_read(reg.UC_ARM64_REG_PC)))
        return False

    def box(self, value):
        if value is None:
            return 0
        addr = self.next_object
        self.next_object += 0x100
        self.objects[addr] = value
        return addr

    def value(self, addr):
        if not addr:
            return None
        if addr in self.objects:
            return self.objects[addr]
        label = m.label(addr)
        if label.startswith('CFString:'):
            return label[9:]
        if addr in m.classes:
            return ('class', m.classes[addr])
        cls = m.class_name(addr)
        if cls and cls != hex(addr):
            return ('class', cls)
        raise RuntimeError('unmodeled object at ' + hex(addr))

    def x(self, index):
        return self.uc.reg_read(getattr(reg, 'UC_ARM64_REG_X' + str(index)))

    def pointer(self, addr):
        return struct.unpack('<Q', self.uc.mem_read(addr, 8))[0]

    def runtime_symbol(self, target):
        # All imported stubs here use ADRP / LDR / BR, including one-hop thunks.
        instructions = list(m.decoder.disasm(bytes(self.uc.mem_read(target, 12)), target))
        if instructions and instructions[0].mnemonic == 'b':
            return self.runtime_symbol(instructions[0].operands[0].imm)
        if len(instructions) >= 2 and instructions[0].mnemonic == 'adrp' and instructions[1].mnemonic == 'ldr':
            slot = instructions[0].operands[1].imm + instructions[1].operands[1].mem.disp
            return '_' + self.imports.get(slot, '').lstrip('_') if slot in self.imports else ''
        return ''

    def hook(self, uc, addr, size, _):
        if addr == self.end:
            uc.emu_stop()
            return
        try:
            ins = next(m.decoder.disasm(bytes(uc.mem_read(addr, size)), addr))
            if ins.mnemonic not in ['bl', 'b']:
                return
            target = ins.operands[0].imm
            selector = m.selector_stub(target)
            symbol = self.runtime_symbol(target) if not selector else ''
            if ins.mnemonic == 'b' and not selector and not symbol:
                return
            native_helpers = {'transPBReplyEnterTypeToStringParam:': 0x10245e8a8, 'replyStatScene': 0x10245e8d0}
            if selector in native_helpers:
                uc.reg_write(reg.UC_ARM64_REG_LR, addr + 4)
                uc.reg_write(reg.UC_ARM64_REG_PC, native_helpers[selector])
                return
            if selector:
                result = self.message(selector)
            elif symbol in ['_objc_retain', '_objc_retainAutoreleasedReturnValue', '_objc_autoreleaseReturnValue']:
                result = self.x(0)
            elif symbol == '_NSStringFromClass':
                result = self.box(self.value(self.x(0))[1]) if self.x(0) else 0
            elif symbol == '_objc_release':
                result = 0
            elif symbol in ['_objc_alloc', '_objc_alloc_init']:
                cls = self.value(self.x(0))
                if cls == ('class', 'NSMutableDictionary'):
                    result = self.box({})
                else:
                    raise RuntimeError('unmodeled allocation: ' + repr(cls))
            elif symbol == '_objc_opt_class':
                result = self.x(0)
            elif symbol == '_objc_opt_isKindOfClass':
                result = self.is_kind(self.value(self.x(0)), self.value(self.x(1)))
            else:
                raise RuntimeError('unmodeled call ' + hex(target) + ' ' + symbol)
            uc.reg_write(reg.UC_ARM64_REG_X0, result)
            next_pc = addr + 4 if ins.mnemonic == 'bl' else uc.reg_read(reg.UC_ARM64_REG_LR)
            if ins.mnemonic == 'bl':
                uc.reg_write(reg.UC_ARM64_REG_LR, next_pc)
            uc.reg_write(reg.UC_ARM64_REG_PC, next_pc)
        except Exception as error:
            self.error = error
            uc.emu_stop()

    @staticmethod
    def is_kind(value, cls):
        names = {'NSString': str, 'NSMutableString': str, 'NSDictionary': dict, 'NSMutableDictionary': dict}
        return int(bool(cls) and cls[0] == 'class' and isinstance(value, names.get(cls[1], type(None))))

    def message(self, selector):
        receiver = self.value(self.x(0))
        self.calls.append(selector)
        if receiver is None:
            return 0
        if selector == 'arrayWithCapacity:':
            return self.box([])
        if selector == 'safeAddObject:':
            value = self.value(self.x(2))
            if value is not None:
                receiver.append(value)
            return 0
        if selector == 'componentsJoinedByString:':
            return self.box(self.value(self.x(2)).join(receiver))
        if selector in ['numberWithBool:', 'numberWithInteger:']:
            return self.box(self.x(2))
        if selector == 'getUserNickName':
            return self.box('FixtureName')
        if selector in ['withTail', 'getAppDelegate']:
            return 0
        if selector == 'initWithCapacity:':
            return self.x(0)
        if selector in ['setObject:forKey:', 'safeSetObject:forKey:', 'setObject:forKeyedSubscript:']:
            value, key = self.value(self.x(2)), self.value(self.x(3))
            if value is not None and key is not None:
                receiver[key] = value
            elif value is None and key is not None and selector == 'setObject:forKeyedSubscript:':
                # NSMutableDictionary's nullable keyed-subscript setter removes
                # the key, unlike setObject:forKey:, which rejects nil values.
                receiver.pop(key, None)
            elif selector != 'safeSetObject:forKey:':
                raise RuntimeError('unexpected nil dictionary insertion')
            return 0
        if selector == 'addEntriesFromDictionary:':
            receiver.update(self.value(self.x(2)) or {})
            return 0
        if selector in ['count', 'length']:
            return len(receiver)
        if selector == 'stringWithFormat:':
            fmt = self.value(self.x(2))
            value = self.pointer(self.uc.reg_read(reg.UC_ARM64_REG_SP))
            if fmt == '%ld':
                return self.box(str(value))
            raise RuntimeError('unmodeled format')
        if selector == 'isEqualToString:':
            return int(receiver == self.value(self.x(2)))
        if selector == 'stringByAppendingString:':
            return self.box(receiver + self.value(self.x(2)))
        if selector in ['sharedInstance', 'getInstance', 'sharedSettings']:
            if receiver not in self.singletons:
                self.singletons[receiver] = self.box(('instance', receiver[1]))
            return self.singletons[receiver]
        if selector in ['existCacheForKeyOnDisk', 'isLocated']:
            return 0  # Synthetic scenario: no shop cache and no location grant.
        if selector == 'sn':
            return 0  # Synthetic scenario: no rich-media upload.
        if selector == 'getUserTBS':
            return self.box('fixture-tbs')
        if selector == 'setParams:':
            self.params = self.value(self.x(2)).copy()
            return 0
        if selector in ['load', 'loadInner', 'loadInnerWithShotConnection']:
            self.loads += 1
            return 0
        if selector in ['setErrorCode:', 'setErrorMsg:', 'setDragVCodeReqParams:', 'setMessageRequestType:', 'setCurrentVc:']:
            return 0
        if receiver == ('instance', 'TBCPbReplayModel'):
            if selector in self.model:
                value = self.model[selector]
                return value if isinstance(value, int) else self.box(value)
            if selector == 'setThreadId:':
                self.model['threadId'] = self.value(self.x(2))
                return 0
        raise RuntimeError('unmodeled selector ' + selector + ' on ' + str(receiver if isinstance(receiver, tuple) else type(receiver).__name__))

    def run(self, model_overrides=None, stack_values=None):
        self.model = {'replyFromStory': 0, 'subPostId': None, 'dragVCodeReqParams': None,
                      'replyFrom': 0, 'bjhItem': None, 'pbEnterType': 0, 'replySubFrom': 0,
                      'params': {}, 'sendOptionalParams': None, 'useProto': 1, 'replyScene': 1, 'replyContainer': 1, 'replyLevel': 0}
        self.model.update(model_overrides or {})
        sp = 0x7000f0000
        args = [self.box(('instance', 'TBCPbReplayModel')), 0,
                self.box('101'), self.box('FixtureForum'), self.box('9'), self.box('0'),
                self.box('Synthetic reply'), 0]
        for i, value in enumerate(args):
            self.uc.reg_write(getattr(reg, 'UC_ARM64_REG_X' + str(i)), value)
        # Stack slot 5 is the controller's explicit isAddition=0. Other nils are explicit scenario inputs.
        for index, value in ({5: "0"} | (stack_values or {})).items():
            self.uc.mem_write(sp + index * 8, struct.pack("<Q", self.box(value)))
        self.uc.reg_write(reg.UC_ARM64_REG_SP, sp)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        try:
            self.uc.emu_start(0x10245d3dc, self.end, count=100000)
        except unicorn.UcError:
            if self.error:
                raise self.error
            raise
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('instruction budget exceeded')
        return {'synthetic': True, 'method': 'TBCPbReplayModel.postPBContentAndFloor…',
                'params': self.params, 'interceptedLoadCount': self.loads, 'selectors': self.calls}
