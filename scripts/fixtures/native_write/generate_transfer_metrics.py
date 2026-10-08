"""Replay the native successful-transport parser's metrics with synthetic data.

No requests or SDKs execute. ObjC scalar property access is substituted; native
parser control flow, path normalization, cost multiplication and result branches
execute from the SHA-checked reference. Missing native logid stays absent.
"""
import argparse
import json
import struct
from pathlib import Path
from emulate_response import Item
from emulate_tbs import TBSResponseEmulator
from emulate_reply import reg
import read_macho as reference


class MetricsEmulator(TBSResponseEmulator):
    def __init__(self, sample):
        self.sample = sample
        self.stat = None
        super().__init__()

    def box(self, value):
        if isinstance(value, Item):
            fields = value.fields
            if 'rawData' in fields and 'netCost' in fields:
                fields['api'] = self.sample['api']
                fields['netCost'] = self.sample['durationSeconds']
                fields['request'].fields['transactionMetric'].fields.update(
                    requestBytes=self.sample['uploadBytes'], responseBytes=self.sample['downloadBytes'])
            if set(fields) == {'logid', 'result'}:
                self.stat = value
        return super().box(value)

    def message(self, selector):
        obj = self.value(self.x(0))
        if isinstance(obj, Item):
            if selector in ['netCost', 'domainLookupDuration', 'connectDuration', 'totalReadAndWriteDuration']:
                value = float(obj.fields[selector])
                self.uc.reg_write(reg.UC_ARM64_REG_D0, struct.unpack('<Q', struct.pack('<d', value))[0])
                return 0
            if selector in ['setCost:', 'setDnsCost:', 'setConCost:', 'setRspCost:']:
                value = struct.unpack('<d', struct.pack('<Q', self.uc.reg_read(reg.UC_ARM64_REG_D0)))[0]
                obj.fields[selector[3].lower() + selector[4:-1]] = value
                return 0
        return super().message(selector)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output must be new')
    samples = []
    for api, duration, code, up, down in [
        ('/c/c/post/add', .125, 0, 1800, 700),
        ('/c/c/thread/add', 1.5, 5, 2500, 810),
        ('/c/c/post/add', .03125, -1, 1930, 512),
        ('c/c/post/add', 0., 0, 0, 0),
    ]:
        sample = dict(api=api, durationSeconds=duration, errorCode=code, uploadBytes=up, downloadBytes=down)
        emulator = MetricsEmulator(sample)
        emulator.run_response(code, {'tid': '101', 'pid': '401'})
        fields = emulator.stat.fields
        expected = {key: fields[key] for key in ['api', 'logid', 'cost', 'result', 'uploadBytes', 'downloadBytes']}
        if expected['result'] >= 2**63:
            expected['result'] -= 2**64
        samples.append(dict(input=sample, expected=expected))
    args.output.write_text(json.dumps(dict(referenceExecutableSHA256=reference.REFERENCE_SHA256,
        scope='Native parsed Protobuf transport metrics; synthetic inputs, no network, no moderation claim.',
        cases=samples), ensure_ascii=False, indent=2) + '\n')
    print('PASS: native transfer metrics cases', len(samples))


if __name__ == "__main__":
    main()
