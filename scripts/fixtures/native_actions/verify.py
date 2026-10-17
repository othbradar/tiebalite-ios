"""Offline field audit against the user-supplied iOS 22.11.1 descriptors."""
import argparse, hashlib, subprocess, tempfile
from pathlib import Path
from google.protobuf import descriptor_pb2 as d
p=argparse.ArgumentParser();p.add_argument('--reference-binary',type=Path,required=True);a=p.parse_args()
b=a.reference_binary.read_bytes()
assert hashlib.sha256(b).hexdigest()=='4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb'
def schema(offset,size): return d.FileDescriptorProto.FromString(b[offset:offset+size])
c=schema(0xa6ef2fc,151219)
refs={'PageRequest':(schema(0xa739a9e,2395),'PbPageReqIdl'), 'PageQuery':(schema(0xa739a9e,2395),'DataReq'),
'PageResponse':(schema(0xa73a486,8379),'PbPageResIdl'),'PageData':(schema(0xa73a486,8379),'DataRes'),
'FloorRequest':(schema(0xa737c52,498),'PbFloorReqIdl'),'FloorQuery':(schema(0xa737c52,498),'DataReq'),
'FloorResponse':(schema(0xa737ed5,650),'PbFloorResIdl'),'FloorData':(schema(0xa737ed5,650),'DataRes')}
refs.update({k:(c,v) for k,v in dict(User='User',Forum='SimpleForum',Thread='ThreadInfo',Post='Post',Subpost='SubPostList',Agree='Agree').items()})
with tempfile.TemporaryDirectory() as tmp:
 out=Path(tmp)/'schema.pb'
 subprocess.run(['protoc','-IConfig/Protobuf',f'--descriptor_set_out={out}','--include_imports','NativeActions.proto'],check=True)
 files=d.FileDescriptorSet.FromString(out.read_bytes())
 local=next(x for x in files.file if x.name=='NativeActions.proto')
 count=0
 for m in local.message_type:
  f,name=refs[m.name];original=next(x for x in f.message_type if x.name==name)
  for field in m.field:
   native=next(x for x in original.field if x.name==field.name)
   assert (field.number,field.type,field.label)==(native.number,native.type,native.label),(m.name,field.name,native)
   count+=1
 print(f'PASS: {len(local.message_type)} native messages, {count} exact fields')
