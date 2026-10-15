"""Verify U12 minimal wire fields against the user's iOS 22.11.1 executable."""
import argparse
import hashlib
import json
from google.protobuf.descriptor_pb2 import FileDescriptorProto, FileDescriptorSet
from pathlib import Path
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-binary', type=Path, required=True)
parser.add_argument('--app-descriptors', type=Path, required=True)
args = parser.parse_args()
binary = args.reference_binary.read_bytes()
assert hashlib.sha256(binary).hexdigest() == '4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb'
native = {}
for offset, length in [(0xa6ef2fc, 151219), (0xa74a2d2, 878), (0xa74a6d5, 417)]:
    file = FileDescriptorProto.FromString(binary[offset:offset + length])
    for message in file.message_type:
        native[file.package + '.' + message.name] = message
app = {file.package + '.' + message.name: message
       for file in FileDescriptorSet.FromString(args.app_descriptors.read_bytes()).file for message in file.message_type}
names = {'TiebaNativeWrite.Common': 'tbclient.CommonReq', 'TiebaNativeWrite.ResponseError': 'tbclient.Error'}
for name, original in [('Request', 'UserPost.UserPostReqIdl'), ('RequestData', 'UserPost.DataReq'),
                       ('Response', 'UserPost.UserPostResIdl'), ('ResponseData', 'UserPost.DataRes'),
                       ('Post', 'PostInfoList'), ('PostContent', 'PostInfoContent')]:
    names['TiebaNativeProfiles.' + name] = 'tbclient.' + original
projections = {('TiebaNativeProfiles.Post', 15): '.tbclient.Abstract',
               ('TiebaNativeProfiles.Post', 16): '.tbclient.Media',
               ('TiebaNativeProfiles.PostContent', 1): '.tbclient.Abstract'}
count = 0
for app_name, native_name in names.items():
    expected = {field.number: field for field in native[native_name].field}
    for field in app[app_name].field:
        original = expected[field.number]
        assert original.name == field.name and original.label == field.label
        if (app_name, field.number) in projections:
            assert field.type == 12 and original.type_name == projections[app_name, field.number]
        else:
            assert original.type == field.type
            if field.type_name:
                assert names[field.type_name.lstrip('.')] == original.type_name.lstrip('.')
        count += 1
print(json.dumps(dict(messages=len(names), fields=count, byteProjections=len(projections))))
