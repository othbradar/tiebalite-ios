"""Generate synthetic U11 wire fixtures from the accepted iOS binary only.

No network, accounts or application execution. Run verify.py separately to
check the app's reduced schema against native field descriptors.
"""
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

def descriptor(offset, length):
    return descriptor_pb2.FileDescriptorProto.FromString(binary[offset:offset + length])

client = descriptor(0xa6ef2fc, 151219)
following_request = descriptor(0xa74a90b, 321)
following_response = descriptor(0xa74aae1, 1616)
hot_request = descriptor(0xa7324fb, 232)
hot_response = descriptor(0xa73268c, 481)
pool = descriptor_pool.DescriptorPool()
# Keep exact native fields used by these fixtures; unrelated client.proto
# messages contain legacy JSON-name collisions and are not needed here.
slim = descriptor_pb2.FileDescriptorProto(name='client.proto', package='tbclient', syntax='proto2')
selection = {'CommonReq': None, 'Error': None,
             'ThreadInfo': ['id', 'tid', 'title', 'fname', 'fid', 'author', 'reply_num'],
             'User': ['id', 'name', 'name_show', 'level_id']}
for name, names in selection.items():
    original = next(m for m in client.message_type if m.name == name)
    copied = slim.message_type.add(name=name)
    for field in original.field:
        if names is None or field.name in names:
            copied.field.add().CopyFrom(field)
pool.Add(slim)
pool.Add(following_request)
pool.Add(hot_request)
for original, fields in [(following_response, {'UserlikeResIdl': None, 'DataRes': [1, 2, 4, 10], 'ConcernData': [1, 3]}),
                         (hot_response, {'HotThreadListResIdl': None, 'DataRes': [2]})]:
    reduced = descriptor_pb2.FileDescriptorProto(name=original.name, package=original.package, syntax='proto2')
    reduced.dependency.append('client.proto')
    for message in original.message_type:
        if message.name not in fields:
            continue
        copied = reduced.message_type.add(name=message.name)
        for field in message.field:
            if fields[message.name] is None or field.number in fields[message.name]:
                copied.field.add().CopyFrom(field)
    pool.Add(reduced)

def wire(name, fields):
    value = message_factory.GetMessageClass(pool.FindMessageTypeByName('tbclient.' + name))()
    json_format.ParseDict(fields, value)
    return base64.b64encode(value.SerializeToString(deterministic=True)).decode('ascii')

common = {'_client_type': '1', '_client_version': '22.11.1', 'sign': 'FIXTURE', '_timestamp': '1700000000000'}
requests = []
for feed, name, business in [
    ('following', 'Userlike.UserlikeReqIdl', {'page_tag': '', 'last_req_unix': '0', 'follow_type': 1, 'load_type': 1}),
    ('following', 'Userlike.UserlikeReqIdl', {'page_tag': 'page-two', 'last_req_unix': '1234', 'follow_type': 1, 'load_type': 2}),
    ('hot', 'HotThreadList.HotThreadListReqIdl', {'tab_id': '1', 'tab_code': 'all'}),
]:
    requests.append(dict(feed=feed, business={key: str(value) for key, value in business.items()}, common=common,
                         wireBase64=wire(name, {'data': dict(business, common=common)})))

author = dict(id='42', name='Author', name_show='Author', level_id=7)
thread = dict(id='110', tid='110', title='Synthetic following', fname='FixtureForum', fid='9',
              author=author, reply_num=5)
responses = []
for feed, name, body in [
    ('following', 'Userlike.UserlikeResIdl', dict(error=dict(errorno=0), data=dict(
        thread_info=[dict(recom_type=1, thread_list=thread), dict(recom_type=1, thread_list=thread),
                     dict(recom_type=3)], page_tag='page-two', has_more=1, req_unix='1234'))),
    ('hot', 'HotThreadList.HotThreadListResIdl', dict(error=dict(errorno=0), data=dict(thread_info=[
        dict(thread, id='210', tid='210', title='Synthetic hot'),
        dict(thread, id='211', tid='211', title='Second hot')]))),
    ('following', 'Userlike.UserlikeResIdl', dict(error=dict(errorno=0), data={})),
    ('hot', 'HotThreadList.HotThreadListResIdl', dict(error=dict(errorno=4))),
]:
    responses.append(dict(feed=feed, wireBase64=wire(name, body)))
args.output.write_text(json.dumps(dict(referenceSHA256=digest, requests=requests, responses=responses), indent=2) + '\n')
print('PASS: 3 native request / 4 response fixtures; synthetic data only')
