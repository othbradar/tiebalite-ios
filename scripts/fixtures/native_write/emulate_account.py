"""Closed, synthetic account and response-state branches of the reference binary."""
import re

from emulate_reply import Emulator, reg

class AccountEmulator(Emulator):
    def message(self, selector):
        receiver = self.value(self.x(0))
        if receiver is None:
            return 0
        if selector == 'getUserUID':
            return self.box(self.uid)
        if selector == 'userInfoDiskKV':
            return self.box(self.cache)
        if selector in ['getStringForKey:', 'stringAtPath:']:
            return self.box(receiver.get(self.value(self.x(2))))
        if selector == 'getUserInLogin:':
            if self.value(self.x(2)) != self.uid:
                raise AssertionError('Account identity changed')
            self.database_reads += 1
            return self.box(self.database)
        if selector == 'setString:forKey:':
            receiver[self.value(self.x(3))] = self.value(self.x(2))
            return 0
        if selector == 'stringWithFormat:' and self.value(self.x(2)) == '%@_tbs':
            value = self.value(self.pointer(self.uc.reg_read(reg.UC_ARM64_REG_SP)))
            return self.box(value + '_tbs')
        if selector == 'fetchTBSWithUId:andBduss:':
            self.fetches.append({'userID': self.value(self.x(2)), 'bduss': self.value(self.x(3))})
            return 0
        return super().message(selector)

    def run_account(self, uid, cached, database):
        self.uid, self.cache, self.database = uid, dict(cached), database
        self.fetches = []
        self.database_reads = 0
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('instance', 'TBCAccountSettings')))
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(0x101c254e8, self.end, count=30000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('instruction budget exceeded')
        return {'returnedTBS': self.value(self.x(0)), 'cacheAfter': self.cache,
                'databaseReads': self.database_reads, 'interceptedFetches': self.fetches}


class HeaderEmulator(Emulator):
    def message(self, selector):
        receiver = self.value(self.x(0))
        if receiver is None:
            return 0
        if selector == 'stringAtPath:':
            return self.box(receiver.get(self.value(self.x(2))))
        if selector == 'regularExpressionWithPattern:options:error:':
            return self.box(re.compile(self.value(self.x(2))))
        if selector == 'firstMatchInString:options:range:':
            return self.box(receiver.search(self.value(self.x(2))))
        if selector == 'rangeAtIndex:':
            start, end = receiver.span(self.x(2))
            self.uc.reg_write(reg.UC_ARM64_REG_X1, end - start)
            return start
        if selector == 'substringWithRange:':
            return self.box(receiver[self.x(2):self.x(2) + self.x(3)])
        return super().message(selector)

    def run_header(self, headers):
        # Fixtures are ASCII, so NSString's UTF-16 ranges equal Python indices.
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('class', 'TBCHandlePostAndReplyVerifyTool')))
        self.uc.reg_write(reg.UC_ARM64_REG_X2, self.box(headers))
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(0x1024769ec, self.end, count=30000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('instruction budget exceeded')
        return self.value(self.x(0))
