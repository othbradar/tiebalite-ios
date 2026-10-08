"""Execute bounded native follow-up parameter/state methods, with no network.

Prepared PB parameters are synthetic inputs, not a replacement for their runtime
provider. The native request dispatch is recorded and never executed. Unknown
calls fail closed; account data and SDKs are not available to this replay.
"""
from emulate_reply import Emulator, reg


class ReplyFollowupEmulator(Emulator):
    def message(self, selector):
        obj = self.value(self.x(0))
        if obj is None:
            return 0
        if selector == 'dictionary' and obj == ('class', 'NSMutableDictionary'):
            return self.box({})
        if selector in ['copy', 'mutableCopy'] and isinstance(obj, dict):
            return self.box(obj.copy())
        if selector == 'dictionaryWithDictionary:':
            return self.box(self.value(self.x(2)).copy())
        if selector == 'safeRemoveObjectForKey:' and isinstance(obj, dict):
            obj.pop(self.value(self.x(2)), None)
            return 0
        if selector in ['numberWithInt:', 'numberWithInteger:']:
            value = self.x(2)
            return self.box(value if value < 2**63 else value - 2**64)
        if selector == 'integerValue' and isinstance(obj, str):
            # Fixtures deliberately use only signed decimal strings accepted
            # without ambiguity by Foundation. No regex/overflow approximation.
            assert obj and obj.lstrip('-').isdecimal()
            return int(obj) & (2**64 - 1)
        if selector == 'loadWithLongConnection:':
            self.dispatches.append(self.x(2))
            return 0
        if selector in ['setParsedDataDict:', 'setParsedListItem:']:
            self.cleared.append(selector)
            assert self.x(2) == 0
            return 0
        if selector == 'isFoldingCommentPage':
            return 0  # Separate legacy folded-page path is not substituted.
        if selector in ['pbCommentArrangeADManager', 'pbBannerArrangeADManager']:
            return 0  # No ad manager is executed in this bounded replay.
        if selector == 'requestParamsToDictionary:commentArrangeADManager:bannerArrangeADManager:sessionRequestTimes:isMultiTab:':
            assert self.x(3) == self.x(4) == self.x(5) == self.x(6) == 0
            self.prepared_base_uses += 1
            return self.box(self.input.get('base'))
        if selector == 'myReplyPostID':
            return self.box(self.input.get('postID'))
        if selector in ['requestParams', 'serverApi']:
            return self.box(('fixture', selector))
        if selector == 'isFoldingComment':
            return int(self.input.get('includesFoldedComments', False))
        if selector == 'state' and obj == ('fixture', 'serverApi'):
            return self.input['serverState']
        if selector == 'setIsRequestMyPostAfterReply:':
            assert self.x(2) == 1
            self.after_reply = True
            return 0
        if selector == 'pbRequestCount':
            return self.request_count
        if selector == 'setPbRequestCount:':
            self.request_count = self.x(2)
            return 0
        if selector == 'params':
            return self.box(self.params)
        return super().message(selector)

    def run_followup(self, kind, inputs):
        self.input = inputs
        self.params = inputs.get('base', {}).copy() if kind == 'load' else None
        self.request_count = inputs.get('requestCount', 0)
        self.after_reply = False
        self.dispatches = []
        self.cleared = []
        self.prepared_base_uses = 0
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('instance', 'FixtureModel')))
        if kind == 'floor':
            address = 0x102f44cec
            self.uc.reg_write(reg.UC_ARM64_REG_X2, self.box(inputs.get('threadID')))
            self.uc.reg_write(reg.UC_ARM64_REG_X3, self.box(inputs.get('postID')))
        elif kind == 'thread':
            address = 0x102c8e7d8
            self.uc.reg_write(reg.UC_ARM64_REG_X2, self.box(('fixture', 'preparedPBParams')))
        else:
            assert kind == 'load'
            address = 0x102c8e620
        self.uc.emu_start(address, self.end, count=10000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('Native follow-up method did not return')
        fields = self.value(self.x(0)) if kind == 'thread' else self.params
        return dict(fields=fields, dispatchModes=self.dispatches,
                    requestCount=self.request_count, afterReply=self.after_reply,
                    cleared=self.cleared, preparedBaseUses=self.prepared_base_uses)
