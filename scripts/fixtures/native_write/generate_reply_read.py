"""Generate native CMD309751 wire fixtures from the accepted iOS descriptors.

Synthetic inputs only. This does not execute providers, open sockets or publish.
The request's prepared page context is an explicit input, not inferred here.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
from google.protobuf import descriptor_pb2, descriptor_pool, json_format, message_factory

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-binary', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
if args.output.exists():
    parser.error('Output must be a new file')
binary = args.reference_binary.read_bytes()
digest = hashlib.sha256(binary).hexdigest()
assert digest == '4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb'


def descriptor(offset, length):
    return descriptor_pb2.FileDescriptorProto.FromString(binary[offset:offset + length])


client = descriptor(0xa6ef2fc, 151219)
request = descriptor(0xa7381ec, 1196)
response = descriptor(0xa738725, 4844)
assert request.name == 'pbList/pbListReq.proto' and response.name == 'pbList/pbListRes.proto'
pool = descriptor_pool.DescriptorPool()
# This projection retains exact native tags/types/presence; unrelated UI fields
# are excluded from synthetic responses. No Android schema supplies these tags.
selection = {'CommonReq': None, 'Error': None, 'ThreadInfo': [1, 2, 3, 4, 18, 27, 28, 61],
             'SimpleForum': [1, 2, 4], 'Page': None, 'User': [1, 2, 3, 4, 5, 23],
             'Post': [1, 3, 4, 5, 13, 19, 23, 37, 43, 44],
             'PbContent': [1, 2], 'Agree': [1, 2, 3, 4, 5]}
slim = descriptor_pb2.FileDescriptorProto(name='client.proto', package='tbclient', syntax='proto2')
for name, numbers in selection.items():
    original = next(message for message in client.message_type if message.name == name)
    copied = slim.message_type.add(name=name)
    for field in original.field:
        if numbers is None or field.number in numbers:
            copied.field.add().CopyFrom(field)
# Request-specific messages are in the native request descriptor itself.
pending = ['AppTransmitData', 'PushInfo']
while pending:
    name = pending.pop()
    if any(message.name == name for message in slim.message_type):
        continue
    original = next(message for message in client.message_type if message.name == name)
    slim.message_type.add().CopyFrom(original)
    pending += [field.type_name.split('.')[-1] for field in original.field if field.type_name]
pool.Add(slim)
pool.Add(request)
read = descriptor_pb2.FileDescriptorProto(name=response.name, package=response.package, syntax='proto2')
read.dependency.append('client.proto')
for message in response.message_type:
    if message.name == 'PbListResIdl':
        read.message_type.add().CopyFrom(message)
    elif message.name == 'DataRes':
        copied = read.message_type.add(name='DataRes')
        for field in message.field:
            if field.number in [1, 2, 5, 6, 7, 8]:
                copied.field.add().CopyFrom(field)
pool.Add(read)


def wire(name, fields):
    value = message_factory.GetMessageClass(pool.FindMessageTypeByName('tbclient.PbList.' + name))()
    json_format.ParseDict(fields, value, ignore_unknown_fields=True)
    return base64.b64encode(value.SerializeToString(deterministic=True)).decode('ascii')


common = {'_client_type': '1', '_client_version': '22.11.1', 'sign': 'fixture-sign',
          '_timestamp': '9007199254740993'}
requests = []
for name, business in [
    ('floor', {'kz': '101', 'last_pid': '430001', 'mark_type': '2'}),
    ('thread', {'kz': '101', 'last_pid': '430001', 'mark_type': '2',
                'request_times': '11', 'session_request_times': '3', 'offset': '2', 'fr': 'frs'}),
    ('wide-id', {'kz': '9007199254740993', 'last_pid': '9007199254740995', 'mark_type': '2'}),
]:
    requests.append(dict(name=name, business=business, common=common,
                         wireBase64=wire('PbListReqIdl', {'data': dict(business, common=common)})))

author = dict(id='42', name='FixtureName', name_show='Fixture Display', level_id=7)
post = dict(id='430001', floor=61, time=1700000000, author=author,
            content=[dict(type=0, text='Synthetic native reply')], agree=dict(agree_num=3, diff_agree_num=3))
data = dict(thread=dict(id='101', tid='101', title='Fixture thread', reply_num=61, author=author),
            forum=dict(id='9', name='FixtureForum'), user_list=[author], post_list=[post],
            page=dict(current_page=3, total_page=3, new_total_page=3, has_more=0))
responses = []
for name, value in [('success', dict(error=dict(errorno=0), data=data)),
                    ('server-rejected', dict(error=dict(errorno=5), data=data)),
                    ('empty-data', dict(error=dict(errorno=0))),
                    ('wrong-thread', dict(error=dict(errorno=0), data=dict(data, thread=dict(id='102', tid='102')))),
                    ('missing-target', dict(error=dict(errorno=0), data=dict(data, post_list=[]))),
                    ('missing-page', dict(error=dict(errorno=0), data={key: value for key, value in data.items() if key != 'page'})),
                    ('unsigned-content-kind', dict(error=dict(errorno=0), data=dict(data, post_list=[
                        dict(post, content=[dict(type=4294967295, text='Must not become ordinary text')])]))),
                    ('success-first-floor', dict(error=dict(errorno=0), data=dict(
                        data, first_floor=dict(post, id='301', floor=1), post_list=[dict(post, floor=2)],
                        page=dict(current_page=1, total_page=1, has_more=0))))]:
    responses.append(dict(name=name, wireBase64=wire('PbListResIdl', value)))
args.output.write_text(json.dumps(dict(referenceExecutableSHA256=digest, command=309751,
                                      requests=requests, responses=responses), indent=2) + '\n')
print(f'PASS: native reply-read descriptor fixtures ({len(requests)} requests, {len(responses)} responses)')
