"""Execute bounded iOS 22.11.1 GIF branches with synthetic values only.

The size branch begins after native metadata preparation, with an explicit byte
length. Stops before digest/network/error presentation. No source images or
accounts are loaded; this does not emulate Apple's image codec or all metadata.
"""
import json
import sys
from pathlib import Path
from emulate_signing import SigningEmulator
from emulate_reply import reg
import read_macho as reference


class GIFPolicyEmulator(SigningEmulator):
    def hook(self, uc, address, size, context):
        if self.mode == 'size' and address in (0x10214c904, 0x10214c87c):
            self.result = address == 0x10214c904
            uc.emu_stop()
            return
        super().hook(uc, address, size, context)

    def message(self, selector):
        if selector == 'runningMeta':
            return self.box(('fixture', 'meta')) if self.image_type is not None else 0
        if selector == 'imageType':
            return self.image_type
        if selector == 'length' and self.value(self.x(0)) == ('fixture', 'encodedGIF'):
            return self.byte_count
        return super().message(selector)

    def run_case(self, mode, value):
        self.mode = mode
        self.result = None
        self.image_type = value if mode == 'type' else None
        self.byte_count = value if mode == 'size' else 0
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.reg_write(reg.UC_ARM64_REG_X0, self.box(('fixture', 'coordinator')))
        self.uc.reg_write(reg.UC_ARM64_REG_X28, self.box(('fixture', 'encodedGIF')))
        self.uc.emu_start(0x102396458 if mode == 'type' else 0x10214c86c, self.end, count=1000)
        if self.error:
            raise self.error
        if mode == 'type':
            return bool(self.x(0))
        if self.result is None:
            raise RuntimeError('Size decision did not reach a known branch boundary')
        return self.result


def main():
    result = {
        'referenceSHA256': reference.REFERENCE_SHA256,
        'scope': 'Native imageType == 2 predicate and post-metadata GIF size decision only; '
                 'synthetic length/provider, no codec, image, SDK or network execution.',
        'types': [{'imageType': value, 'gif': GIFPolicyEmulator().run_case('type', value)}
                  for value in [None, 0, 1, 2, 3]],
        'sizes': [{'byteCount': value, 'accepted': GIFPolicyEmulator().run_case('size', value)}
                  for value in [1, 5_242_880, 10_485_759, 10_485_760, 10_485_761]],
    }
    Path(sys.argv[1]).write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
