"""Run the native reply-compose content method with synthetic editor inputs.

Only Foundation primitives and the already prepared text-editor values are
substituted. No UI, account/SDK, verification, upload or network is executed.
"""
from emulate_reply import Emulator, reg


class ReplyContentEmulator(Emulator):
    def hook(self, uc, address, size, context):
        # respondsToSelector: is an imported runtime call, not an ObjC stub.
        if address == 0x1023deaec:
            uc.reg_write(reg.UC_ARM64_REG_X0, int(self.input['supportsServerText']))
            uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
            uc.reg_write(reg.UC_ARM64_REG_PC, address + 4)
            return
        super().hook(uc, address, size, context)

    def message(self, selector):
        receiver = self.value(self.x(0))
        if receiver is None:
            return 0
        objects = {
            'textEditorService': 'FixtureEditor', 'pluginContext': 'FixtureContext',
            'tb_typedModel': 'FixtureComposeModel', 'legacyReplyModel': 'FixtureReplyModel'
        }
        if selector in objects:
            return self.box(('instance', objects[selector]))
        inputs = {
            'currentTextForServer': 'serverText', 'currentText': 'visibleText',
            'atMeString': 'recipientPrompt', 'uPortrait': 'portrait', 'uNameShow': 'displayName'
        }
        if selector in inputs:
            return self.box(self.input[inputs[selector]])
        if selector == 'isFloor':
            return int(self.input['isFloor'])
        if selector == 'isFromRotateCode':
            return 0  # First explicit submission, never verification replay.
        if selector == 'length' and isinstance(receiver, str):
            return len(receiver.encode('utf-16-le')) // 2
        if selector == 'predicateWithFormat:':
            assert self.value(self.x(2)) == 'SELF MATCHES %@'
            pattern = self.value(self.pointer(self.uc.reg_read(reg.UC_ARM64_REG_SP)))
            assert pattern == r'回复 [\s\S]* :'
            return self.box(('predicate', pattern))
        if selector == 'evaluateWithObject:':
            assert receiver[0] == 'predicate'
            value = self.value(self.x(2))
            assert value == self.input['recipientPrompt']
            return int(self.foundation_match)
        if selector == 'stringWithFormat:':
            assert self.value(self.x(2)) == '回复 #(reply, %@, %@) :'
            sp = self.uc.reg_read(reg.UC_ARM64_REG_SP)
            portrait = self.value(self.pointer(sp))
            name = self.value(self.pointer(sp + 8))
            assert isinstance(portrait, str) and isinstance(name, str)
            return self.box('回复 #(reply, ' + portrait + ', ' + name + ') :')
        return super().message(selector)

    def run_content(self, inputs, foundation_match):
        self.input = inputs
        self.foundation_match = foundation_match
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('instance', 'TBCReplyComposeSubmitPlugin')))
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(0x1023deab0, self.end, count=10000)
        if self.error:
            raise self.error
        if self.uc.reg_read(reg.UC_ARM64_REG_PC) != self.end:
            raise RuntimeError('Native content method did not finish')
        result = self.value(self.x(0))
        assert isinstance(result, str)
        return result
