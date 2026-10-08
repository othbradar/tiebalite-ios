"""Native pure-text business builder; all non-Foundation inputs are explicit synthetic values."""
from unicorn import arm64_const as reg
from emulate_reply import Emulator
import read_macho as m

class ThreadEmulator(Emulator):
    def message(self, selector):
        receiver = self.value(self.x(0))
        objects = {
            ('fixture','plugin'): {'threadInfoItem':('fixture','item'), 'pluginContext':('fixture','context')},
            ('fixture','item'): self.item,
            ('fixture','context'): {'composeContainerConfig':None,'entranceType':1,'composeType':0},
        }
        if isinstance(receiver,tuple) and receiver in objects and selector in objects[receiver]:
            value = objects[receiver][selector]
            return value if isinstance(value,int) else self.box(value)
        if selector == 'convertContent:' and receiver == ('fixture','plugin'):
            return self.x(2)  # Explicit plain-text conversion substitute, not a rich-text test.
        if selector == 'stringWithFormat:':
            fmt = self.value(self.x(2))
            value = self.pointer(self.uc.reg_read(reg.UC_ARM64_REG_SP))
            if fmt == '%@': return self.box(str(self.value(value)))
            if fmt == '%d': return self.box(str(value & 0xffffffff))
        if selector == 'countByEnumeratingWithState:objects:count:' and receiver == []:
            return 0
        if selector == 'safeSetString:forKey:':
            value, key = self.value(self.x(2)), self.value(self.x(3))
            if value is not None: receiver[key] = value
            return 0
        return super().message(selector)

    def run_thread(self, overrides=None):
        self.item = {'content':'Synthetic thread','title':'Fixture title','fid':'9','fName':'FixtureForum',
                     'postPrefix':None, 'transmit':None,'isPostToMyPage':False,'photos':[],
                     'tabId':None,'tabName':None,'isGeneralTab':False,'voteItem':None,
                     'isForumBusinessAccount':False,'isShowVirtualImage':False,'isQuestion':False,
                     'ext':None,'sendThreadCategory':0}
        self.item.update(overrides or {})
        self.uc.reg_write(reg.UC_ARM64_REG_X0,self.box(('fixture','plugin')))
        self.uc.reg_write(reg.UC_ARM64_REG_SP,0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR,self.end)
        self.uc.emu_start(0x1018b4d2c,self.end,count=100000)
        if self.error: raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC)!=self.end: raise RuntimeError('instruction budget exceeded')
        return self.value(self.x(0))
