"""Compare the reduced app schema to iOS 22.11.1 native descriptors offline."""
import argparse
import hashlib
import json
from pathlib import Path
from google.protobuf.descriptor_pb2 import FileDescriptorProto, FileDescriptorSet

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-binary', type=Path, required=True)
parser.add_argument('--app-descriptors', type=Path, required=True)
args = parser.parse_args()
binary = args.reference_binary.read_bytes()
assert hashlib.sha256(binary).hexdigest() == '4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb'
native = {}
for offset, length in [(0xa6ef2fc, 151219), (0xa74a90b, 321), (0xa74aae1, 1616), (0xa7324fb, 232), (0xa73268c, 481)]:
    file = FileDescriptorProto.FromString(binary[offset:offset + length])
    for message in file.message_type:
        native[file.package + '.' + message.name] = message
app = {file.package + '.' + message.name: message
       for file in FileDescriptorSet.FromString(args.app_descriptors.read_bytes()).file for message in file.message_type}
names = {'TiebaNativeWrite.Common': 'tbclient.CommonReq', 'TiebaNativeWrite.ResponseError': 'tbclient.Error'}
for app_name, native_name in [('FollowingRequest', 'Userlike.UserlikeReqIdl'), ('FollowingRequestData', 'Userlike.DataReq'),
                              ('FollowingResponse', 'Userlike.UserlikeResIdl'), ('FollowingData', 'Userlike.DataRes'),
                              ('FollowingPageData', 'Userlike.PageData'),
                              ('ConcernData', 'Userlike.ConcernData'), ('HotRequest', 'HotThreadList.HotThreadListReqIdl'),
                              ('HotRequestData', 'HotThreadList.DataReq'), ('HotResponse', 'HotThreadList.HotThreadListResIdl'),
                              ('HotData', 'HotThreadList.DataRes')]:
    names['TiebaNativeExplore.' + app_name] = 'tbclient.' + native_name
count = 0
for app_name, native_name in names.items():
    expected = {field.number: field for field in native[native_name].field}
    for field in app[app_name].field:
        original = expected[field.number]
        assert original.label == field.label, (app_name, field.name, 'cardinality')
        if (app_name, field.number) in [('TiebaNativeExplore.ConcernData', 1), ('TiebaNativeExplore.HotData', 2)]:
            assert field.type == 12 and original.type_name == '.tbclient.ThreadInfo'
        elif (app_name, field.number) == ('TiebaNativeExplore.FollowingPageData', 1):
            assert field.type == 12 and original.type_name == '.tbclient.LayoutFactory'
        else:
            assert original.type == field.type, (app_name, field.name, 'wire type')
            if field.type_name:
                assert names[field.type_name.lstrip('.')] == original.type_name.lstrip('.')
        count += 1
print(json.dumps(dict(messages=len(names), fields=count, byteProjections=['ConcernData.thread_list', 'HotData.thread_info',
                                                                      'FollowingPageData.feed_list'])))
