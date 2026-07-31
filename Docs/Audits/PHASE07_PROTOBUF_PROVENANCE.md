# 阶段 07 Personalized Protobuf provenance

状态：`LOCAL_BUILD_VERIFIED` / `CROSS_LANGUAGE_GENERATED_FIXTURE`

## 输入边界

- Android reference：`References/TiebaLite-Android`
- exact commit：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- exact root：`app/src/main/protos/Personalized.proto`
- manifest：`Config/Protobuf/Personalized.inputs.tsv`
- closure：root 1、direct 4、transitive 46，总计 51
- direct imports：`CommonRequest.proto`、`ThreadInfo.proto`、
  `AppPosInfo.proto`、`Error.proto`
- enum count：0

生成脚本逐项验证 commit、submodule clean、输入 SHA-256、直接 import、
root/direct/transitive 分类，并将 `protoc --dependency_out` 解析结果与 manifest
精确比较。`.proto` 没有复制进 iOS 树；`n0099` 不是输入。

## 工具与输出

- `protoc 35.1`
- `protoc-gen-swift 1.38.1`
- SwiftProtobuf runtime/package `1.38.1`
- package revision：`55d7a1cc5666b85c13464aea1c4b4a90feccb4c8`
- canonical lock：`Config/SwiftPM/Package.resolved`
- options：
  `Visibility=Public,FileNaming=FullPath,UseAccessLevelOnImports=false`
- output：`Generated/Protobuf` 51 个 `.pb.swift`、
  `GENERATED_SHA256SUMS`、`GENERATION_METADATA.txt`

`scripts/verify_protos.sh` 从两个独立临时目录生成，并比较两者及 tracked
output。生成文件不含绝对 repo path、SwiftUI/UIKit 或 UI/Feature import。

## Swift 6 边界

1.38.1 generator 对 10 个复杂 copy-on-write message 输出
`@unchecked Sendable`。ADR-0011 接受的只是 exact generated output：静态门禁
锁定文件名单和数量，手写源码仍禁止 unchecked/preconcurrency。raw message
只在 Core/TiebaAPI 的同步 decode/map 过程存在；结构化任务测试只把
`RecommendationPage` 等普通 Sendable domain 值送出。

## JVM fixture

- path：
  `TestSupport/Fixtures/API/Recommendations/personalized_cross_language.pb`
- byte count：250
- SHA-256：
  `54a838f8bd05c39e90b84b3bba4d4224dc81fe11b63934e23dd65be937eebb4a`
- producer：`scripts/fixtures/PersonalizedFixtureGenerator.java`
- producer runtime：`protobuf-java 4.35.1`
- Maven published SHA-1：`b933d3f9fc35b0356f28980c2ffc5892d297eebf`
- locked jar SHA-256：
  `a4345ba2aa009912ff6f90467fea2d104605256b72c50840d75f13256638a472`
- exact source：
  `https://repo.maven.apache.org/maven2/com/google/protobuf/protobuf-java/4.35.1/protobuf-java-4.35.1.jar`
- Java/Javac：21.0.10

Producer 使用 Java `DynamicMessage` 和同一 descriptor set，不链接 Swift
generated code。fixture 只有 synthetic ID/text；不含 Cookie、BDUSS、STOKEN、
授权头、设备标识、真实正文或第三方媒体。两次 JVM generation 与 tracked
bytes 相同。`make bootstrap-fixture-tools` 校验 SHA-1/SHA-256 后原子安装
ignored cache；quality 本身离线，cache 缺失、symlink 或 hash 错误均失败。

Proto 与 fixture 默认输出、临时自定义输出都在写入前做 lexical/realpath
containment，并拒绝允许根以下的 ancestor/target symlink；Proto output tree
存在任意内部 symlink 也会失败。隔离门禁包含相应拒绝 canary。

## 已验证行为

- Personalized request protobuf byte golden；
- Android static call-site 的 multipart boundary、`data/file` part 与
  `X-BD-Data-Type` header；
- response/error/data message presence；
- optional explicit default 与 absent；
- unknown field 2047 round-trip；
- raw integer `999`；
- present empty data、missing data、nonzero service error；
- empty/truncated/unterminated malformed body；
- server order、raw `id/threadId` 分离和 public author whitelist mapper；
- generated/UI/project/package/capture isolation。

## 不能从本证据推出

- 匿名 live server 接受最小请求；
- response MIME、错误码和值域；
- CommonRequest/AppPos/设备/session 的最小集合；
- 推荐终止、重复页和稳定排序；
- Wire 6.4.0 的所有实现细节；
- 公开分发、App Store、商业使用或 schema 法律权利。

这些项继续在 `Specs/UNKNOWN_BEHAVIORS.md` 与 ADR-0011 中保持
`UNKNOWN/BLOCKED`。
