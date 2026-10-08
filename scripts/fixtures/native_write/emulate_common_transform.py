"""Native dynamic Common through signed return, with synthetic provider boundaries.

Static Common is explicitly supplied from a separate native replay. SDK/account
providers remain substitutes; this is not execution of the complete client.
"""
from emulate_dynamic_common import DynamicCommonEmulator
from emulate_signing import CommonSigningEmulator
from emulate_reply import reg
import read_macho as reference


class CommonTransformEmulator(DynamicCommonEmulator, CommonSigningEmulator):
    def pre_sign(self, address):
        super().pre_sign(address)
        return False

    def hook(self, uc, address, size, context):
        if address in [0x1024b3458, 0x1024b45b0]:
            self.signed = self.value(self.x(19 if address == 0x1024b3458 else 21)).copy()
            uc.emu_stop()
            return
        try:
            instruction = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
            if instruction.mnemonic in ['bl', 'b']:
                selector = reference.selector_stub(instruction.operands[0].imm)
                if selector == 'getSignWithParams:':
                    uc.reg_write(reg.UC_ARM64_REG_LR, address + 4)
                    uc.reg_write(reg.UC_ARM64_REG_PC, 0x1024b4638)
                    return
            super().hook(uc, address, size, context)
        except Exception as error:
            self.error = error
            uc.emu_stop()

    def run_signed(self, context, static, business, metrics, metadata):
        self.metadata = metadata
        self.additional_signature = None
        self.additional_signature_inputs = []
        self.signed = None
        result = self.run_dynamic(context, static, business, metrics)
        if self.signed is None:
            raise RuntimeError('did not reach native signed Common return')
        result['signedCommon'] = self.signed
        return result
