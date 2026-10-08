"""Native static Common construction with explicit synthetic provider snapshots.

Executes both native cached and recomputed branches. OS/SDK/device/consent/sync
getters and NSDateFormatter have explicit substitutes. No provider initialization,
real identity, clock, SDK access key, account, filesystem or network is available.
"""
import struct
from emulate_signing import SigningEmulator
from emulate_reply import reg
import read_macho as reference


class CommonEmulator(SigningEmulator):
    def hook(self, uc, address, size, context):
        try:
            instruction = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
            if instruction.mnemonic in ['bl', 'b']:
                target = instruction.operands[0].imm
                symbol = self.runtime_symbol(target)
                if symbol in ['_objc_alloc', '_objc_alloc_init']:
                    cls = self.value(self.x(0))
                    if cls in [('class', 'IDPConfig'), ('class', 'NSDateFormatter')]:
                        self.finish_call(address, instruction, self.box(('instance', cls[1])))
                        return
            super().hook(uc, address, size, context)
        except Exception as error:
            self.error = error
            uc.emu_stop()

    def message(self, selector):
        obj = self.value(self.x(0))
        if obj is None:
            return 0
        if selector == 'tbEnableYaloggerLog':
            return 0
        if selector in self.values:
            value = self.values[selector]
            if selector in ['imageQualityFlag']:
                return value
            return self.box(value)
        if selector in ['currentDevice', 'mainScreen', 'syncData', 'date']:
            return self.box(('instance', selector))
        if selector == 'initWithNameSpace:':
            assert self.value(self.x(2)) == 'kTBCPermissionPolicyShowTimeNameSpace'
            return self.x(0)
        if selector == 'boolForKey:':
            assert self.value(self.x(2)) == 'kTBCPermissionPolicyShowTimeKey'
            return self.privacy_policy_shown
        if selector == 'setDateFormat:':
            assert self.value(self.x(2)) == 'YYYYMMdd'
            return 0
        if selector == 'stringFromDate:':
            return self.box(self.event_day)
        if selector == 'resolutionIphoneOnlyNew':
            for index, value in enumerate(self.resolution):
                self.uc.reg_write(getattr(reg, 'UC_ARM64_REG_D' + str(index)),
                                  struct.unpack('<Q', struct.pack('<d', value))[0])
            return 0
        if selector == 'scale':
            self.uc.reg_write(reg.UC_ARM64_REG_D0, struct.unpack('<Q', struct.pack('<d', self.scale))[0])
            return 0
        if selector == 'stringWithFormat:':
            fmt = self.value(self.x(2))
            stack = self.uc.reg_read(reg.UC_ARM64_REG_SP)
            if fmt == '%.1f':
                return self.box('%.1f' % struct.unpack('<d', self.uc.mem_read(stack, 8))[0])
            if fmt == '%ld':
                return self.box(str(struct.unpack('<q', self.uc.mem_read(stack, 8))[0]))
        if selector == 'containsObject:':
            return int(self.value(self.x(2)) in obj)
        if selector == 'safeRemoveObjectForKey:':
            obj.pop(self.value(self.x(2)), None)
            return 0
        if selector == 'stringAtPath:':
            return self.box(obj.get(self.value(self.x(2))))
        if selector == 'copy':
            return self.box(obj.copy())
        return super().message(selector)

    PROVIDERS = {
        'clientVersion': 'tbcClientVersion', 'systemVersion': 'systemVersion', 'deviceScore': 'deviceScore',
        'deviceFamily': 'familyString', 'devicePlatform': 'tbcPlatformString', 'channel': 'getChannelID',
        'cuid': 'defaultCuid', 'legoVersion': 'legoLibVersion', 'browserCuid': 'bbaCUID',
        'browserInstanceID': 'bbaIID', 'advertisingID': 'idfa', 'sampleID': 'sampleId',
        'vendorID': 'identifierForVendor', 'mac': 'macaddress', 'sdkVersion': 'smSDKVersion',
        'frameworkVersion': 'smCorePackageVersion', 'gameVersion': 'smGameVersion',
        'imageQuality': 'imageQualityFlag', 'pureMode': 'pureMode', 'miniAppMode': 'xcxMode',
    }

    def run_static(self, context, mode):
        assert mode in ['cached', 'recomputed']
        self.values = {selector: context[key] for key, selector in self.PROVIDERS.items()}
        self.event_day = context['eventDay']
        self.privacy_policy_shown = int(context['privacyPolicyShown'])
        self.resolution = (context['screenWidth'], context['screenHeight'])
        self.scale = context['screenScale']
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('class', 'TBCServerAPI')))
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(0x100249eb0 if mode == 'cached' else 0x1024b12c4, self.end, count=100000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('instruction budget exceeded')
        # Snapshot the observed dictionary so later emulated cache mutations do
        # not rewrite the evidence of an earlier call.
        return self.value(self.x(0)).copy()
