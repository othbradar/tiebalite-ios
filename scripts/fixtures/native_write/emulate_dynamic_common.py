"""Native pre-sign Common execution with explicit synthetic runtime-provider values.

No actual SDK, login, device, account, clock or network implementation is invoked.
Executes standard/optimized construction and the native safe-string helper; stops
before signing and reports the consumed synthetic previous-request metrics.
"""
import base64
import struct
from emulate_common import CommonEmulator
from emulate_reply import reg
import read_macho as reference


class DynamicCommonEmulator(CommonEmulator):
    def pre_sign(self, address):
        self.result = self.value(self.x(26 if address == 0x1024b2f94 else 24)).copy()
        self.path = 'standard' if address == 0x1024b2f94 else 'optimized'
        return True

    def hook(self, uc, address, size, context):
        if address in [0x1024b2f94, 0x1024b435c] and self.pre_sign(address):
            uc.emu_stop()
            return
        try:
            instruction = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
            if instruction.mnemonic in ['bl', 'b']:
                target = instruction.operands[0].imm
                symbol = self.runtime_symbol(target)
                selector = reference.selector_stub(target)
                if symbol == '_objc_opt_new':
                    assert self.value(self.x(0)) == ('class', 'NSMutableDictionary')
                    self.finish_call(address, instruction, self.box({}))
                    return
                if symbol == '_NSClassFromString':
                    name = self.value(self.x(0))
                    assert name == 'TBClientBrowseModeManager'
                    self.finish_call(address, instruction, self.box(('class', name)))
                    return
                if symbol == '_objc_opt_respondsToSelector':
                    name = reference.string(self.x(1))
                    assert name == 'tb_serverAPI_browseModeParameter'
                    self.finish_call(address, instruction, int(self.input['hasBrowseModeProvider']))
                    return
                if selector == 'addExtraParamsWithRequestParams:':
                    uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
                    uc.reg_write(reg.UC_ARM64_REG_PC, 0x1024b3804)
                    return
                if selector == 'safeSetString:forKey:':
                    uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
                    uc.reg_write(reg.UC_ARM64_REG_PC, 0x10265b6f8)
                    return
            super().hook(uc, address, size, context)
        except Exception as error:
            self.error = error
            uc.emu_stop()

    def double(self, value):
        self.uc.reg_write(reg.UC_ARM64_REG_D0, struct.unpack('<Q', struct.pack('<d', value))[0])
        return 0

    def message(self, selector):
        obj = self.value(self.x(0))
        if obj is None:
            return 0
        self.trace.append(selector)
        if obj is self.metrics:
            if selector in ['api', 'logid', 'result', 'uploadBytes', 'downloadBytes']:
                value = obj[selector]
                return self.box(value) if selector == 'api' else value
            if selector == 'cost':
                return self.double(obj['cost'])
            mutations = {'setApi:': 'api', 'setLogid:': 'logid', 'setCost:': 'cost',
                         'setResult:': 'result', 'setUploadBytes:': 'uploadBytes',
                         'setDownloadBytes:': 'downloadBytes'}
            if selector in mutations:
                assert self.x(2) == 0 or selector == 'setCost:'
                obj[mutations[selector]] = None if selector == 'setApi:' else 0
                return 0
        if selector == 'commonStaticParameters':
            return self.box(self.static.copy())
        if selector in self.PROVIDERS:
            return self.box(self.input[self.PROVIDERS[selector]])
        if selector in self.SCALARS:
            return int(self.input[self.SCALARS[selector]])
        if selector == 'needRenameSensParam':
            return 1  # Proto argument is false; neither native path may rename.
        if selector in ['isHttpsRequest', 'stokenLeakFixSwitch']:
            return 1
        if selector == 'api':
            return self.box(self.input['api'])
        if selector == 'containsString:':
            return int(self.value(self.x(2)) in obj)
        if selector == 'reqParams':
            return self.box(self.business)
        if selector == 'timeIntervalSince1970':
            return self.double(self.input['timestampSeconds'])
        if selector == 'firstLaunchActiveInterval':
            return self.double(self.input['activeTimestampSeconds'])
        if selector == 'logItem':
            return self.box(('instance', 'FixtureLaunchLog'))
        if selector == 'initWithNameSpace:':
            assert self.value(self.x(2)) == 'kTBCPersonalizedSwitchConfigNameSpace'
            return self.x(0)
        if selector == 'stringForKey:':
            assert self.value(self.x(2)) == 'personalizedSwitch'
            return self.box(self.input['storedPersonalizedSwitch'])
        if selector == 'resolvedString:':
            assert self.value(self.x(2)) == 'ZGlhYw=='
            return self.box(base64.b64decode(self.value(self.x(2))).decode())
        if selector == 'numberWithUnsignedInteger:':
            return self.box(self.x(2))
        if selector == 'stringValue':
            return self.box(str(obj))
        if selector == 'stringWithFormat:':
            fmt = self.value(self.x(2))
            stack = self.uc.reg_read(reg.UC_ARM64_REG_SP)
            if fmt in ['%.0f', '%f']:
                return self.box(fmt % struct.unpack('<d', self.uc.mem_read(stack, 8))[0])
            if fmt == '%llu':
                return self.box(str(self.pointer(stack)))
            if fmt == '%u':
                return self.box(str(self.pointer(stack) & 0xffffffff))
            if fmt == '%@':
                value = self.value(self.pointer(stack))
                return self.box('(null)' if value is None else str(value))
        return super().message(selector)

    PROVIDERS = {
        'sampleId': 'sampleID', 'tb_serverAPI_browseModeParameter': 'browseMode',
        'client_id': 'clientID', 'extra': 'extra', 'personalizedSwitch': 'personalizedSwitch',
        'netTypeForReport': 'networkType', 'userAgent': 'userAgent',
        'getUserBDUSS': 'sessionValue', 'getUserStoken': 'secondaryValue',
        'SSDK_zid': 'opaqueSDKValue', 'getUserTBS': 'tbs', 'diacInfo': 'diac',
        'launchScheme': 'launchScheme',
    }
    SCALARS = {
        'isEnableSignOptMode': 'signOptimizationEnabled', 'isCoverSignForumOnly': 'signForumOnly',
        'isCoverAll': 'signAll', 'shouldKeepAlive': 'keepAlive', 'shouldGoSmallFlow': 'smallFlow',
        'launchType': 'launchType',
    }

    def run_dynamic(self, context, static, business, metrics, include_request_params=False):
        self.input, self.static, self.business = context, static, business
        self.metrics = dict(metrics)
        self.values, self.trace = {}, []
        self.result = None
        self.uc.mem_write(0x10ebbfe78, struct.pack('<Q', self.box(self.metrics)))
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('instance', 'TBCServerAPI')))
        self.uc.reg_write(reg.UC_ARM64_REG_X2, int(include_request_params))
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(0x1024b1e74, self.end, count=100000)
        if self.error:
            raise self.error
        if self.result is None:
            raise RuntimeError('did not reach native pre-sign boundary')
        return {'fields': self.result, 'metricsAfter': self.metrics, 'path': self.path}
