"""Read-only, bounded static inspection of the user-supplied 22.11.1 binary."""
import hashlib
import os
import subprocess
import json
import struct
from pathlib import Path
import capstone

BINARY = Path(os.environ['TIEBALITE_NATIVE_REFERENCE'])
data = BINARY.read_bytes()
REFERENCE_SHA256 = '4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb'
if hashlib.sha256(data).hexdigest() != REFERENCE_SHA256:
    raise ValueError('Reference executable does not match the accepted 22.11.1 SHA256')
relocations = json.loads(subprocess.check_output(['rabin2', '-Rj', str(BINARY)], stderr=subprocess.DEVNULL))
if isinstance(relocations, dict):
    relocations = relocations['relocs']
segments, sections, symbols, methods = [], {}, {}, {}
offset = 32
function_starts = []
text_base = 0
function_data = None
for _ in range(struct.unpack_from('<I', data, 16)[0]):
    command, length = struct.unpack_from('<II', data, offset)
    if command == 0x19:
        vm, size, fileoff, filesize = struct.unpack_from('<QQQQ', data, offset + 24)
        segments.append((vm, filesize, fileoff))
        if data[offset + 8:offset + 24].split(b"\0")[0] == b"__TEXT":
            text_base = vm
        for i in range(struct.unpack_from('<I', data, offset + 64)[0]):
            p = offset + 72 + 80 * i
            name = data[p:p + 16].split(b'\0')[0].decode()
            addr, size, fileoff = struct.unpack_from('<QQI', data, p + 32)
            sections[name] = (addr, size, fileoff)
    elif command == 2:
        symoff, count, stroff, strsize = struct.unpack_from('<IIII', data, offset + 8)
        for i in range(count):
            p = symoff + 16 * i
            si, kind, sec, desc, addr = struct.unpack_from('<IBBHQ', data, p)
            if addr and si < strsize:
                end = data.find(b'\0', stroff + si, stroff + strsize)
                symbols[addr] = data[stroff + si:end].decode(errors='replace')
    elif command == 0x26:
        function_data = struct.unpack_from("<II", data, offset + 8)
    offset += length

if function_data:
    p, length = function_data
    end = p + length
    addr = text_base
    while p < end:
        shift = value = 0
        while p < end:
            byte = data[p]
            p += 1
            value |= (byte & 127) << shift
            if not byte & 128:
                break
            shift += 7
        if value == 0:
            break
        addr += value
        function_starts.append(addr)

def function_end(addr):
    import bisect
    return function_starts[bisect.bisect_right(function_starts, addr)]

classes = {}

def file_offset(addr):
    for vm, size, offset in segments:
        if vm <= addr < vm + size:
            return offset + addr - vm
    raise ValueError(hex(addr))

def pointer(addr):
    return struct.unpack_from('<Q', data, file_offset(addr))[0]

def string(addr):
    try:
        p = file_offset(addr)
        end = data.find(b'\0', p, p + 240)
        if end < 0:
            return ''
        s = data[p:end].decode('utf-8')
        return s if s and all(c.isprintable() for c in s) else ''
    except (ValueError, UnicodeDecodeError):
        return ''

def in_section(addr, name):
    base, size, _ = sections.get(name, (0, 0, 0))
    return base <= addr < base + size

def class_name(addr):
    if not addr:
        return '(external)'
    if addr in classes:
        return classes[addr]
    try:
        return string(pointer((pointer(addr + 32) & ~7) + 24))
    except ValueError:
        return hex(addr)

def label(addr):
    if addr in methods:
        return methods[addr]
    if addr in classes:
        return classes[addr]
    if addr in symbols:
        return symbols[addr]
    if in_section(addr, '__cfstring'):

        try:
            flags = pointer(addr + 8)
            count = pointer(addr + 24)
            start = file_offset(pointer(addr + 16))
            encoding, size = ('utf-16-le', count * 2) if flags & 16 else ('utf-8', count)
            return 'CFString:' + data[start:start + size].decode(encoding)
        except (ValueError, UnicodeDecodeError):
            return 'CFString:(unresolved)'
    if in_section(addr, '__objc_selrefs'):
        return 'selector:' + string(pointer(addr))
    if in_section(addr, '__objc_classrefs'):
        return 'class:' + class_name(pointer(addr))
    if in_section(addr, '__cstring') or in_section(addr, '__objc_methname'):
        return 'string:' + string(addr)
    return ''

decoder = capstone.Cs(capstone.CS_ARCH_ARM64, capstone.CS_MODE_ARM)
decoder.detail = True

def selector_stub(addr):
    if not in_section(addr, '__objc_stubs'):
        try:
            p = file_offset(addr)
            thunk = list(decoder.disasm(data[p:p + 4], addr))
        except ValueError:
            return ''
        if len(thunk) != 1 or thunk[0].mnemonic != 'b':
            return ''
        addr = thunk[0].operands[0].imm
        if not in_section(addr, '__objc_stubs'):
            return ''
    p = file_offset(addr)
    ins = list(decoder.disasm(data[p:p + 8], addr))
    if len(ins) == 2 and ins[0].mnemonic == 'adrp' and ins[1].mnemonic == 'ldr':
        return string(pointer(ins[0].operands[1].imm + ins[1].operands[1].mem.disp))
    return ''
