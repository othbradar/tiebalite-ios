"""22.11.1 image business builder; synthetic objects, no upload/account/SDK.

Stop at accessAPI, before any transport or completion. Explicit Foundation and
weak-reference substitutes do not stand in for compression or network behavior.
"""
import json
import struct
import sys
from pathlib import Path
from emulate_signing import SigningEmulator
from emulate_tbs import TBSCommonEmulator
from emulate_common import CommonEmulator
from emulate_reply import reg
import read_macho as reference


class ImageUploadEmulator(SigningEmulator):
    def hook(self, uc, address, size, context):
        try:
            ins = next(reference.decoder.disasm(bytes(uc.mem_read(address, size)), address))
            if ins.mnemonic in ['bl', 'b']:
                symbol = self.runtime_symbol(ins.operands[0].imm)
                selector = reference.selector_stub(ins.operands[0].imm)
                if selector == 'accessAPI:WithParams:files:completionBlock:':
                    self.result = {'api': self.value(self.x(2)),
                                   'fields': self.value(self.x(3)).copy(),
                                   'files': self.value(self.x(4)).copy()}
                    uc.emu_stop()
                    return
                if symbol in ['_objc_initWeak', '_objc_copyWeak']:
                    value = self.x(1) if symbol == '_objc_initWeak' else self.pointer(self.x(1))
                    uc.mem_write(self.x(0), struct.pack('<Q', value))
                    self.finish_call(address, ins, value)
                    return
            super().hook(uc, address, size, context)
        except Exception as error:
            self.error = error
            uc.emu_stop()

    def message(self, selector):
        obj = self.value(self.x(0))
        if obj == ('fixture', 'chunk') and selector in self.input['chunk']:
            value = self.input['chunk'][selector]
            return value if isinstance(value, int) else self.box(value)
        if obj == ('fixture', 'model') and selector in self.input['model']:
            value = self.input['model'][selector]
            return value if isinstance(value, int) else self.box(value)
        if selector == 'serverApi':
            return self.box(('fixture', 'server'))
        if selector == 'readWaterMarkConfig':
            return self.input['watermark']
        if selector == 'getUserName':
            return self.box('FixtureName')
        if selector == 'numberWithInt:':
            return self.box(self.x(2))
        if selector == 'dictionaryWithDictionary:':
            return self.box(self.value(self.x(2)).copy())
        if selector == 'dictionaryWithObjects:forKeys:count:':
            return self.box({self.value(self.pointer(self.x(3) + 8 * i)):
                             self.value(self.pointer(self.x(2) + 8 * i)) for i in range(self.x(4))})
        if selector == 'stringWithFormat:':
            fmt = self.value(self.x(2))
            value = self.pointer(self.uc.reg_read(reg.UC_ARM64_REG_SP))
            if fmt in ['%d', '%lu']:
                return self.box(str(value))
        return super().message(selector)

    def run_upload(self, values):
        self.input = values
        self.result = None
        for index, value in {0: self.box(('fixture', 'model')), 2: self.box(('fixture', 'chunk')),
                             3: values['saveOrigin']}.items():
            self.uc.reg_write(getattr(reg, 'UC_ARM64_REG_X' + str(index)), value)
        self.uc.reg_write(reg.UC_ARM64_REG_SP, 0x7000f0000)
        self.uc.reg_write(reg.UC_ARM64_REG_LR, self.end)
        self.uc.emu_start(0x10214f384, self.end, count=30000)
        if self.error:
            raise self.error
        if self.result is None:
            raise RuntimeError('did not reach intercepted upload boundary')
        return self.result


def main():
    cases = []
    for name, mark, setting, forum, last in [
        ('reply-single', 0, 0, 'FixtureForum', 1),
        ('reply-intermediate', 0, 0, 'FixtureForum', 0),
        ('no-forum', 0, 0, '', 1),
        ('forum-watermark', 1, 2, 'FixtureForum', 1),
        ('name-watermark', 1, 1, 'FixtureForum', 1),
        ('watermark-off', 1, 3, 'FixtureForum', 1),
    ]:
        values = dict(chunk=dict(imgMd5='0123456789ABCDEF0123456789ABCDEF', imageData='synthetic-bytes',
                                 isFinish=last, chunkCurrNum=1, imageWidth=640, imageHeight=480,
                                 dataSize=600000, smlImageWidth=0, smlImageHeight=0),
                      model=dict(shouldAddWaterMark=mark, isSensitive=0, isBjh=0, barName=forum),
                      watermark=setting, saveOrigin=0)
        cases.append(dict(name=name, input=values, expected=ImageUploadEmulator().run_upload(values)))
    forms = []
    source = json.loads(Path('TestSupport/Fixtures/API/Write/native-ios-tbs.json').read_text())
    for seed in source['signingCases']:
        emulator = TBSCommonEmulator()
        context = seed['input'] | {'api': '/c/s/uploadPicture'}
        static = CommonEmulator().run_static(seed['staticContext'], 'recomputed')
        business = cases[0]['expected']['fields']
        emulator.metadata = {}
        emulator.additional_signature = None
        emulator.additional_signature_inputs = []
        emulator.signed = None
        result = emulator.run_dynamic(context, static, business, seed['metrics'], include_request_params=True)
        assert emulator.signed is not None
        forms.append(dict(name=seed['name'], input=context, staticContext=seed['staticContext'],
                          business=business, metrics=seed['metrics'], expected=emulator.signed))
    result = dict(referenceSHA256=reference.REFERENCE_SHA256,
                  scope='Native uploadChunk:saveOrigin: at 0x10214f384; synthetic Foundation/provider values. '
                        'Stopped before accessAPI. Common/signing executes native with synthetic OS/SDK/account '
                        'inputs. Excludes compression, HTTP and server.', cases=cases, forms=forms)
    Path(sys.argv[1]).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')


if __name__ == '__main__':
    main()
