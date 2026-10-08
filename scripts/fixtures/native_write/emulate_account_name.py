"""Native profile-to-account nickname update with entirely synthetic objects.

Executes the UID guard and name selection/update part of the native profile
completion. Unrelated profile/cache/permission effects are intercepted; no actual
account database, notification center, SDK, profile request or app is invoked.
"""
import struct
from emulate_reply import Emulator, reg


class AccountNameEmulator(Emulator):
    def hook(self, uc, address, size, context):
        if address in [0x101e1a0a4, 0x101e1a23c]:
            self.reached_boundary = True
            uc.emu_stop()
            return
        super().hook(uc, address, size, context)

    def message(self, selector):
        obj = self.value(self.x(0))
        if obj is None:
            return 0
        if selector == 'getUserUID':
            return self.box(self.input['accountID'])
        if selector == 'getUserNickName':
            return self.box(self.input['cachedName'])
        if selector == 'profile':
            return self.box(('instance', 'FixtureProfile'))
        if selector == 'user':
            return self.box(('instance', 'FixtureProfileUser'))
        if selector in ['uID', 'uNameShow', 'uName']:
            key = {'uID': 'profileID', 'uNameShow': 'displayName', 'uName': 'loginName'}[selector]
            return self.box(self.input[key])
        if selector in ['loginUserUK', 'tiebaUid', 'privateSetsItem', 'antiStat', 'shouldHandleBarEntryGuideStatus']:
            return 0  # Explicit absent unrelated profile values / disabled guide.
        if selector in ['updateUK:', 'setTiebaUID:', 'savePermissionConfig:', 'setCachedProfile:',
                        'setIsUpdateCacheProfile:', 'reGetLoginUserData']:
            return 0  # No host side effects or persistence.
        if selector == 'updateUserNickName:':
            self.updated.append(self.value(self.x(2)))
            return 1
        if selector == 'saveUDisplayNameToLogin:unameshow:':
            self.saved.append({'userID': self.value(self.x(2)), 'name': self.value(self.x(3))})
            return 0
        if selector == 'defaultCenter':
            return self.box(('instance', 'FixtureNotificationCenter'))
        if selector == 'postNotificationName:object:':
            assert self.value(self.x(2)) == 'kTBCUserNickNameUpdateNotification'
            self.notifications += 1
            return 0
        return super().message(selector)

    def run_name(self, context):
        self.input = context
        self.updated, self.saved, self.notifications = [], [], 0
        self.reached_boundary = False
        block = self.box(('fixture-block', 'profile-completion'))
        model = self.box(('instance', 'TBCPersonalInfoModel'))
        self.uc.mem_write(block + 0x20, struct.pack('<Q', model))
        self.uc.reg_write(reg.UC_ARM64_REG_X0, block)
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(0x101e19970, self.end, count=30000)
        if self.error:
            raise self.error
        if not self.reached_boundary:
            raise RuntimeError('did not reach native nickname boundary')
        return dict(updated=self.updated, saved=self.saved, notifications=self.notifications)
