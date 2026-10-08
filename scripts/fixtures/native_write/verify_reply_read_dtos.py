"""Audit reused read-only DTO wire shapes against the native iOS descriptor.

The legacy descriptor set is produced by protoc from the locked DTO closure,
not from a request builder. This verifies compatibility; it does not designate
Android request behavior as an iOS source of truth.
"""
import argparse
import hashlib
import json
from pathlib import Path
from google.protobuf.descriptor_pb2 import FileDescriptorProto, FileDescriptorSet

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-binary', type=Path, required=True)
parser.add_argument('--dto-descriptors', type=Path, required=True)
args = parser.parse_args()
binary = args.reference_binary.read_bytes()
assert hashlib.sha256(binary).hexdigest() == '4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb'
native = FileDescriptorProto.FromString(binary[0xa6ef2fc:0xa6ef2fc + 151219])
existing = FileDescriptorSet.FromString(args.dto_descriptors.read_bytes())
native_messages = {message.name: message for message in native.message_type}
dto_messages = {message.name: message for file in existing.file for message in file.message_type}
seen, fields = set(), 0
pending = ['ThreadInfo', 'Post', 'Page', 'User', 'SimpleForum']
exceptions = []
while pending:
    name = pending.pop()
    if name in seen:
        continue
    seen.add(name)
    expected = {field.number: field for field in native_messages[name].field}
    for field in dto_messages[name].field:
        observed = expected[field.number]
        assert field.label == observed.label, (name, field.name, 'cardinality')
        assert field.type_name.split('.')[-1] == observed.type_name.split('.')[-1], (name, field.name, 'message')
        if field.type != observed.type:
            # A content-kind discriminator, not an ID or numeric value. Both are
            # ordinary varints. The adapter rejects >Int32.max before DTO mapping.
            assert (name, field.number, field.type, observed.type) == ('PbContent', 1, 5, 13)
            exceptions.append('PbContent.type: uint32 -> checked int32')
        fields += 1
        if field.type_name:
            pending.append(field.type_name.split('.')[-1])
print(json.dumps(dict(messages=len(seen), fields=fields, exceptions=exceptions,
                      dtoDescriptorSHA256=hashlib.sha256(args.dto_descriptors.read_bytes()).hexdigest())))
