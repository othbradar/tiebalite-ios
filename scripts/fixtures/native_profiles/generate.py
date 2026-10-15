"""Generate credential-free U12 fixtures from native iOS descriptors offline."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
from google.protobuf import descriptor_pb2, descriptor_pool, json_format, message_factory
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-binary', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
binary = args.reference_binary.read_bytes()
digest = hashlib.sha256(binary).hexdigest()
assert digest == '4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb'
client = descriptor_pb2.FileDescriptorProto.FromString(binary[0xa6ef2fc:0xa6ef2fc + 151219])
pool = descriptor_pool.DescriptorPool()
slim = descriptor_pb2.FileDescriptorProto(name='client.proto', package='tbclient', syntax='proto2')
selected = {'CommonReq': None, 'Error': None,
            'PostInfoList': ['thread_id', 'post_id', 'title', 'user_id', 'forum_name', 'name_show']}
for name, fields in selected.items():
    original = next(m for m in client.message_type if m.name == name)
    target = slim.message_type.add(name=name)
    for field in original.field:
        if fields is None or field.name in fields:
            target.field.add().CopyFrom(field)
pool.Add(slim)
request = descriptor_pb2.FileDescriptorProto.FromString(binary[0xa74a2d2:0xa74a2d2 + 878])
response = descriptor_pb2.FileDescriptorProto.FromString(binary[0xa74a6d5:0xa74a6d5 + 417])
pool.Add(request)
slim = descriptor_pb2.FileDescriptorProto(name=response.name, package=response.package, syntax='proto2')
slim.dependency.append('client.proto')
for message in response.message_type:
    target = slim.message_type.add(name=message.name)
    for field in message.field:
        if message.name != 'DataRes' or field.name in ['post_list', 'hide_post']:
            target.field.add().CopyFrom(field)
pool.Add(slim)
def wire(name, fields):
    value = message_factory.GetMessageClass(pool.FindMessageTypeByName('tbclient.UserPost.' + name))()
    json_format.ParseDict(fields, value)
    return base64.b64encode(value.SerializeToString(deterministic=True)).decode()
common = {'_client_type': '1', '_client_version': '22.11.1', 'sign': 'FIXTURE', '_timestamp': '1700000000000'}
requests = []
for section, page in [('threads', 1), ('replies', 1), ('threads', 2)]:
    business = dict(uid='42', rn='20', pn=str(page), need_content='1', is_thread='1' if section == 'threads' else '0', is_view_card='0')
    if page == 2:
        business['last_thread_time'] = '1234'
    requests.append(dict(section=section, business=business, common=common,
                         wireBase64=wire('UserPostReqIdl', dict(data=dict(business, common=common)))))
post = dict(thread_id='110', post_id='111', title='Synthetic', user_id='42', forum_name='Fixture', name_show='Author')
responses = [wire('UserPostResIdl', dict(error=dict(errorno=0), data=dict(post_list=[post]))),
             wire('UserPostResIdl', dict(error=dict(errorno=0), data=dict(hide_post=1)))]
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(dict(referenceSHA256=digest, requests=requests, responses=responses), indent=2) + '\n')
print('PASS: 3 requests / 2 responses from native iOS descriptors; synthetic data only')
