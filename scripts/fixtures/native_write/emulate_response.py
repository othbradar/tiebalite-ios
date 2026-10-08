"""Replay native response and account-verification decisions with synthetic objects.

The transport has already completed. IDL decoding is explicitly substituted;
account/verification UI effects and telemetry are only recorded, never executed.
No request, credential read, retry, or network operation is available.
"""
import struct
from emulate_reply import Emulator, reg
import read_macho as reference

class Item:
    def __init__(self, fields):
        self.fields = fields


class ResponseEmulator(Emulator):
    ERROR_PREDICATES = {
        'sms': 0x101c8c9e8, 'forbidden': 0x101c8cb20,
        'realName': 0x101c8cb34, 'captcha': 0x101c8cb44,
        'antiAbuse': 0x101c8cb54, 'illegalWords': 0x101c8cb64,
        'postingFrequency': 0x101c8cb74, 'muted': 0x101c8cb84,
        'appealing': 0x101c8cb94, 'forumMCNRestriction': 0x101c8cbfc,
    }

    def hook(self, uc, address, size, context):
        try:
            instruction = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
            if instruction.mnemonic in ['bl', 'b']:
                target = instruction.operands[0].imm
                # Explicit logging sinks, not an arbitrary unknown-function stub.
                if target == 0x102650070 or self.runtime_symbol(target) == '_NSLog':
                    self.log_count += 1
                    next_pc = address + 4 if instruction.mnemonic == 'bl' else self.x(30)
                    uc.reg_write(reg.UC_ARM64_REG_X0, 0)
                    uc.reg_write(reg.UC_ARM64_REG_PC, next_pc)
                    return
            super().hook(uc, address, size, context)
        except Exception as error:
            self.error = error
            uc.emu_stop()

    @staticmethod
    def is_kind(value, cls):
        if cls == ('class', 'TBCIMBaseMessageItem'):
            return int(isinstance(value, Item))
        if cls == ('class', 'NSNumber'):
            return int(isinstance(value, int))
        return Emulator.is_kind(value, cls)

    def message(self, selector):
        obj = self.value(self.x(0))
        if obj is None:
            return 0
        if selector == 'userInfo' and isinstance(obj, dict):
            return self.box(obj.get('userInfo'))
        if selector in ['deleteAccountAndGotoLogin', 'bindMobile:', 'verifyID:', 'modifyPWD', 'verifyFace']:
            self.pass_actions.append(selector)
            return 0  # Intercept the UI/account effect; do not execute it.
        if selector == 'characterAtIndex:':
            return ord(obj[self.x(2)])
        if selector == 'substringFromIndex:':
            return self.box(obj[self.x(2):])
        if selector == 'objectForKey:':
            return self.box(obj.get(self.value(self.x(2))))
        if selector in ['intValue', 'integerValue', 'longLongValue', 'unsignedLongLongValue']:
            return int(obj) & 0xffffffffffffffff
        if selector in ['numberWithLong:', 'numberWithInt:']:
            return self.box(self.x(2))
        if selector == 'decodeDataWith:requestCMD:':
            assert self.x(3) in [309730, 309731]
            self.decode_count += 1
            return self.box(self.decoded)
        if selector == 'itemToDynamicDictionary':
            return self.box(obj.fields.copy())
        if selector in ['stringAtPath:', 'dictAtPath:', 'numberAtPath:']:
            for key in self.value(self.x(2)).split('/'):
                obj = obj.get(key) if isinstance(obj, dict) else None
            return self.box(obj)
        if selector == 'dictionaryWithObjects:forKeys:count:':
            return self.box({self.value(self.pointer(self.x(3) + i * 8)):
                             self.value(self.pointer(self.x(2) + i * 8)) for i in range(self.x(4))})
        if selector == 'errorWithDomain:code:userInfo:':
            return self.box(dict(domain=self.value(self.x(2)), code=self.x(3), userInfo=self.value(self.x(4))))
        if selector == 'sendLog:':
            self.log_count += 1
            return 0
        if selector == 'isReachable' and obj == ('instance', 'TBCReachabilityService'):
            return 0  # Fixture suppresses the optional network-error telemetry alert.
        if selector == 'stringWithFormat:':
            # Only native diagnostic text in this method; not request/response data.
            self.log_formats.append(self.value(self.x(2)))
            return self.box('synthetic-diagnostic')
        if isinstance(obj, Item):
            fields = obj.fields
            if selector.startswith('set') and selector.endswith(':'):
                key = selector[3].lower() + selector[4:-1]
                if key in ['state', 'result', 'logid', 'uploadBytes', 'downloadBytes']:
                    fields[key] = self.x(2)
                elif key in ['cost', 'dnsCost', 'conCost', 'rspCost']:
                    fields[key] = 0  # Metrics have no branching role in fixture.
                else:
                    fields[key] = self.value(self.x(2))
                return 0
            if selector in fields:
                value = fields[selector]
                return value if isinstance(value, int) else self.box(value)
            raise RuntimeError('unmodeled response property ' + selector)
        return super().message(selector)

    def run_response(self, error_code, body, raw=b'synthetic-wire', command=309731):
        self.log_count, self.decode_count, self.log_formats = 0, 0, []
        self.decoded = dict(data=Item(body), error=Item(dict(errorNum=str(error_code), errorMsg='fixture-error', logid=None)))
        self.api = Item(dict(api='/c/c/post/add', netCost=0, state=3, rawData=raw,
                             requestCMD=command, useProto=1, logid=None,
                             request=Item(dict(transactionMetric=Item(dict(domainLookupDuration=0, connectDuration=0,
                             totalReadAndWriteDuration=0, requestBytes=1, responseBytes=len(raw),
                             response=Item(dict(statusCode=200))))))))
        stat = Item(dict(logid=0, result=0))
        self.uc.mem_write(0x10ebbfe78, struct.pack('<Q', self.box(stat)))
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(self.api))
        self.uc.reg_write(reg.UC_ARM64_REG_X2, 1)
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(0x1024b5db0, self.end, count=100000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('instruction budget exceeded')
        error = self.api.fields.get('error')
        parsed = self.api.fields.get('protobufParserData')
        return dict(state=self.api.fields['state'], decodeCount=self.decode_count,
                    hasError=error is not None, errorInfo=error.get('userInfo') if error else None,
                    parsedFields=parsed.fields if parsed else None)

    def run_pass(self, error_code, pass_value):
        self.pass_actions = []
        manager = Item({})
        info = dict(errno=error_code, errInfo=dict(pass_token=pass_value))
        api = Item(dict(error=dict(userInfo=info)))
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(manager))
        self.uc.reg_write(reg.UC_ARM64_REG_X2, self.box(api))
        self.uc.reg_write(reg.UC_ARM64_REG_X3, 0)
        self.execute_method(0x1021fcf10)
        return dict(handled=bool(self.x(0)), actions=list(self.pass_actions))

    def predicates(self, error_code):
        matches = []
        for name, address in self.ERROR_PREDICATES.items():
            self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('instance', 'TBCUEGManager')))
            self.uc.reg_write(reg.UC_ARM64_REG_X2, error_code & 0xffffffffffffffff)
            self.execute_method(address)
            if self.x(0):
                matches.append(name)
        return matches

    def execute_method(self, address):
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(address, self.end, count=100000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('instruction budget exceeded')
