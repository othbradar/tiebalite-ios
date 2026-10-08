# R09 text-write fixtures

## Current beta3 contract (2026-10-07)

The user explicitly withdrew U08 response compatibility and receipt-driven refresh. The historical notes below do not describe the current candidate. U08WriteReceiptTests now asserts the exact beta3 MIME allowlist and anti-field precedence, including rejection of application/protobuf. R09 captcha coverage is restored unchanged from the tag. The UI mock uses a supported application/octet-stream receipt with no anti metadata; it is synthetic, not a Live capture. U08ReplyTests verifies ordinary current-page refresh, retained pages/anchor, failure preservation, and no automatic follow-up page. Superseded tests/source are backed up in ignored beta3-alignment/before artifacts; no Live moderation claim is made. Frozen outbound snapshots remain unchanged.


No private account or write response is captured. R09 WritePreflight records only allowlisted HTTP/MIME/type metadata from anonymous and in-App account preflights; fixed JSON below remains synthetic. `Tests/R09WriteRepositoryTests.swift` constructs deterministic minimal account JSON (fixture-only tbs/uid) and AddPost responses using the locked schema; thread success/error/captcha JSON is constructed inline. `R09WriteFixture` records exact parent202/subpost303/thread101/forum90/user44; these are synthetic and never sent to a network.

`HarnessMockHTTPClient` intercepts every repository request. Tests validate HTTPS destination, login metadata→write ordering, active lease invalidation, no write Cookie, one submission, and returned server IDs. `R09ComposerTests` adds duplicate suppression, failure retention, cancellation/late receipt rejection and per-target/session drafts. `DebugR09ComposerGallery` always owns FixtureTextWriteRepository independently of the full App's Live service.

Android source: UI c5f1125f, ReplyPage/ReplyViewModel, MixedTiebaApiImpl.addPostFlow/addThreadFlow, MiniTiebaApi.addThreadFlow, OfficialTiebaApi.loginFlow, ProtobufRequest, SortAndSignInterceptor, AddThreadBean. AddPost/Anti schemas locked at protocol5545326b (unchanged between reference commits).

Verified: HTTPS login metadata returns application/x-javascript with valid JSON (uid is a string). Unknowns: HTTPS compatibility of Android's HTTP c.tieba.baidu.com new-thread route; minimal iOS fields without Android device identifiers; account risk restrictions and live server error-code taxonomy. No automated write probe is permitted. User-only Live validation is a separate gate. No initNickName call, device fingerprint imitation, CAPTCHA bypass or transport downgrade.

Regression: accountMetadataJavaScriptMIMEReportsServerFailureWithoutPublishing uses minimized anonymous error_code1 with the observed application/x-javascript MIME, asserts the typed server error and no subsequent write. Existing success pipeline now uses the same MIME. replyMultipartIncludesAndroidInterceptorFieldsAndSignature covers the previously missed CommonParamInterceptor→SortAndSignInterceptor path, auth/client/from outer fields, headers, and exclusion of the binary data part from signing. New-thread receipt test uses the same JSON converter MIME and retains positive pid/tid and CAPTCHA checks.

R10: R10ImageUploadTests uses synthetic 512003-byte input and fixed chunk1/chunk2 JSON (fixture_pic/640/480) through HarnessMockHTTPClient. It verifies sequential multipart chunks, signature fields, fixed non-login Cookie, error termination/no retry. R10ComposerStateTests checks draft order/9-limit/delete, failed upload retention, skip-successful retry, no final write on cancellation or changed lease, and local preview cache reuse. UITESTING-only gallery creates five small numbered JPEGs and holds one Mock upload on an explicit continuation, then fails once; no delays or live endpoint. Production has no gallery or Mock upload completion button.

2026-10-07 U08 receipt regression: user-triggered Live AddPost returned HTTP200 and application/protobuf with valid Protobuf, positive pid and matching tid. The old MIME allowlist rejected it before decoding. U08WriteReceiptTests constructs a minimal response with synthetic pid401/tid101, never captured user content. It verifies all three reply targets through LiveTextWriteRepository backed by HarnessMockHTTPClient, single submission, Composer receipt, existing MIME compatibility, and rejection of malformed/missing/wrong-thread/captcha/server-error/HTML responses. UITESTING FixtureReplyRefreshRepository returns a synthetic response of the same MIME through the production pipeline so the UI regression covers automatic dismissal, reply refresh, retained position and sent-draft clearing.

U08 follow-up: anti/info fields are not a replacement for the authoritative receipt. Additional synthetic fixtures exercise zero/type descriptors, md5/URL, need_vcode and access-state metadata with and without a valid successful receipt. No actual Live anti field value was captured or inferred. Per the Android interceptor→repository chain, zero error plus positive bound pid is success; nonzero error never is. The older captcha fixture now includes an explicit server rejection alongside its ID and challenge flag, preserving rejection coverage instead of assuming any metadata can negate an otherwise successful receipt. Missing IDs with actual challenge fields still report verification, while type descriptors alone report unknown. UI fixtures include anti type0/access-state metadata to reproduce the old early rejection.

2026-09-27 display-name regression: metadata uid42 is followed by the existing anonymous Profile endpoint. The synthetic response has a different login name and display name (Unicode and form-reserved characters); AddPost and new-thread form must retain only the exact display name. Missing display name remains empty, never a UI/login fallback. Wrong uid, offline, revoked lease and cancellation during profile fetch must stop before publishing. The profile request contains no session credentials. This verifies the business-field chain only; it is not a moderation test or a captured Live response.

2026-10-07 U08 outbound compatibility: beta3-request-snapshots.json is generated OFFLINE from TextWriteProtocol at published commit4534020d509ea0188dced53cf582fcc775dbb71e with fixture-session/fixture-token, synthetic account42 and R09WriteFixture targets. Fixed draft title is `Fixture title`, content is `Synthetic reply + & #滑稽`. It records all HTTPRequest properties (body as SHA256), not captured traffic. Request builder, authorizer, boundary/User-Agent dependencies matched that tag before the fix; source equality evidence and the temporary baseline generator are retained only in ignored request-compatibility artifacts. The temporary duplicate protocol was removed from the test target. Red comparison differed only in Accept for all three replies; new-thread request was equal. The final regression compares the current production request to these frozen values, while existing Mock response tests keep application/protobuf support and one-send checks. This proves request compatibility for synthetic inputs, not server moderation retention.
# Native iOS 22.11.1 migration fixtures

`native-ios-request-url.json` replays only the native short-connection URL block
at 0x100249044–0x100249168. Six synthetic cases cover the two write commands,
existing-query separator, short-as-long routing and inactive/zero-command paths.
The native instructions append `cmd` and `format=protobuf`; Foundation strings
and model getters are explicit substitutes, and execution stops before dispatch.
This corrects the former unsupported Swift test assumption that a Proto write
uses a query-less URL. Existing body/header/signature fixtures remain unchanged.

```sh
PYTHONDONTWRITEBYTECODE=1 \
TIEBALITE_NATIVE_REFERENCE=Artifacts/VisualReview/U08/official-ios-22.11.1/TBClient \
python3 scripts/fixtures/native_write/emulate_url.py
```

`native-ios-reply-followup.json` executes three bounded native methods for the
post-reply `getmypost` read: floor parameters, ordinary-thread parameter
transformation, and the initial request-state gate. Its 16 synthetic cases retain
the receipt ID, remove stale page selectors, and verify that native states 1/2
do not dispatch or increment the request count. The prepared PB context is an
explicit substitute; dispatch is intercepted. This is not a Simulator build of
the official app, a full request/response replay, or evidence of moderation.
Nil/empty floor-builder cases do not bypass the controller's nonempty-ID guard.
Swift tests normalize native NSNumber/string parameter values to the existing
string encoding boundary, including an integer ID beyond IEEE-754 exact range.

```sh
python3 scripts/fixtures/native_write/generate_reply_followup.py \
  --reference-binary Artifacts/VisualReview/U08/official-ios-22.11.1/TBClient \
  --verify TestSupport/Fixtures/API/Write/native-ios-reply-followup.json
```

`native-ios-reply-content.json` executes the actual reply-compose submit plugin's
first-submission content preparation (16 synthetic editor contexts). It preserves
server text, fallback rules, recipient-prefix conditions and the absence of the
legacy delegate's 140-unit truncation. It does not select the runtime experiment,
convert attachments, replay verification, upload or publish. The Foundation
predicate is executed by a development-only Apple Foundation helper; Simulator
tests check primitive parity, including width folding of the fullwidth colon.
The original Python-regex oracle mismatch is retained under ignored artifacts.

```sh
python3 scripts/fixtures/native_write/generate_reply_content.py \
  --reference-binary Artifacts/VisualReview/U08/official-ios-22.11.1/TBClient \
  --verify TestSupport/Fixtures/API/Write/native-ios-reply-content.json
```

`native-ios-account-name.json`执行原生profile完成块的账号UID检查及昵称更新部分，
11例验证显示名优先、空缺时回退profile登录名、错账号/无变化不更新及字面保留。
profile/cache/DB/通知均为封闭合成对象或拦截出口，不访问实际账号，也不启动资料请求。
这验证昵称进入缓存的规则，不把它等同于完整Passport登录或账号持久准备。

`native-ios-static-common.json`执行原生静态公共参数的缓存/重算路径，9序列共15步；
`native-ios-dynamic-common.json`执行标准/优化动态路径，24例同时核对字段和消费后的
上一请求统计。系统/SDK/账号/隐私/同步配置/时钟全是显式合成provider输入，不从宿主读取。
nil、空字符串和缺省值按各自原生setter语义区分；优化分支的统计字段仍使用普通setter。
`native-ios-common-transform.json`再穿过动态构造、业务合并和原生签名返回，共6例，
独立descriptor验证最终Common的编码；只有标准分支追加包版本/实验元数据。
静态Common输入来自独立静态回放，未执行真实provider初始化、实际账号存储或网络。
这不证明整个原版客户端已经运行，也不证明平台审核留存结果。

`native-ios-business-parameters.json` contains five synthetic plain-text cases
produced by offline ARM64 execution of the supplied reference's business methods.
`native-ios-request-encoding.json` is encoded independently with the reference's
FileDescriptorProto messages and Python Protobuf. It proves schema/field presence,
not a capture of the reference's complete HTTP request. The `thread-schema` case
explicitly supplies an IDL-only business `sig`; its presence is not evidence that
the native send path emits that field. Rich-text conversion, uploads, runtime
CommonReq providers, signing, verification, and moderation are outside these fixtures.

Reproduce the native fixtures without changing checked-in fixtures:

```sh
python3 scripts/fixtures/native_write/generate.py \
  --reference-binary Artifacts/VisualReview/U08/official-ios-22.11.1/TBClient \
  --verify TestSupport/Fixtures/API/Write
```

The executable is not included in Git. The tool checks its SHA256 before parsing
or emulation. It uses the already installed development tools `rabin2`, Unicorn
2.1.2, Capstone 5.0.9 and Python Protobuf 7.36.0; none is linked into the App.
Foundation, account, location and send boundaries are explicit synthetic substitutes;
unimplemented calls fail. Reply execution reaches one intercepted load; the thread
fixture executes only its parameter builder. No host app, network, actual posting,
SDK identity, personal files or credentials are used.


`native-ios-account-state.json` 使用同一参考SHA，由 `scripts/fixtures/native_write/generate.py` 生成/核对。6个账号分支与6个Set-Cookie提取分支真正执行对应ARM64方法；所有账号、TBS、会话值和Foundation/KV/DB都是合成替身，补取出口仅计数，未联网。fixture包含输入及结果，不是实网账号或安全上下文。它不证明原版持久化清理、TBS HTTP请求或验证码完成。


`native-ios-http-envelope.json` 的4组样本执行原生 `addExtraHttpHeaders` 和
`appendPartWithFileData`，核对参数准备后的header与原始二进制文件段。
UA、logID、svcp_stk都是显式合成输入；调用方data/data/image/jpeg参数来自
静态调用链。测试复用前述独立IDL字节，检查Swift封装与原生结果一致、无Android
外层表单/查询/额外请求头。AF header遍历无稳定顺序保证，断言采用等价header集合与
确定的multipart格式，不把样本标成完整官方实网字节抓包。

`native-ios-signing.json` 的5组样本执行真实合并/签名/返回分支及原生MD5格式化，
覆盖业务覆盖、签名后元数据及Common未知sig字段丢弃；Swift输出再与独立IDL字节比较。
输入Common是明确的合成上下文，CC_MD5使用等价离线primitive；SDK可选sig为显式不透明替身，
未执行SDK、读取账号或获得真实安全上下文。它证明签名边界，不证明完整原生发送或审核留存。

2026-10-07 native response rules: `native-ios-response-rules.json` replays 22 UEG scalar predicates, 30 account-action inputs, and 3 parser-state inputs. IDL decoding and UI/account effects are explicit substitutes, not Live execution. `native-ios-response-decoding.json` contains 13 synthetic response messages encoded independently using selected fields of the supplied iOS descriptors. It covers both native response envelopes, metadata accompanying success, explicit server rejection, identity-verification material presence/absence, unknown/negative codes, and missing/wrong IDs. The Swift decoder does not expose generated messages to Views or turn unrelated metadata into a verification failure. Local positive-ID/target correlation is a separate guard, not a claim that the complete native UI completion has been reproduced. No fixture is a captured user response or evidence of moderation retention.

### 原生条件请求 Cookie

`native-ios-cookies.json`由22.11.1的addExtraCookieParams/shouldKeepAlive/shouldGoSmallFlow真实方法产生，包含12组纯合成网络/配置输入。Foundation Cookie创建是明确替身；没有访问全局Cookie jar、HTTP DNS、真实账号或网络。Swift侧使用系统HTTPCookie生成请求头，并直接验证经现有transport仅发送一次且全局Cookie处理仍关闭。该fixture与原`native-ios-http-envelope.json`的无Cookie范围分开；旧11份fixture保持逐字节一致。不是完整官方请求抓包或服务端审核证明。

### 原生 TBS 准备

`native-ios-tbs.json` 单独生成，以免反复执行未变更的既有回放。2个普通表单Common/签名样本执行原生标准/优化分支和URL名单检查；22个JSON样本执行实际parser、stringAtPath与TBS完成块。原来的Common fixture仅提供显式合成provider输入，新的期望结果由本次原生方法产生。Foundation原语替换、数据库/通知拦截；无真实账号、网络或SDK执行。表单字符集和最终timeout来自静态证据，另用Swift直接回归；不把它们当成该JSON fixture的运行内容。

```sh
python3 scripts/fixtures/native_write/generate_tbs.py \
  --reference-binary /absolute/path/to/accepted/TBClient \
  --fixtures TestSupport/Fixtures/API/Write \
  --verify TestSupport/Fixtures/API/Write/native-ios-tbs.json
```

旧12份fixture保持不变；生成新文件可用`--output`替代`--verify`，目标必须不存在。未知调用立即失败，回放不开放网络出口。该结果不是完整Live迁移或审核留存证明。

### 原生发送组件组合

`native-ios-client.json`把先前已原生回放的5组纯文字业务字段与实际动态Common/签名方法组合，再由原生IDL描述符独立编码。运行时参数全部显式合成；它为Swift整个发送组件链的完整multipart字节提供独立期望，不是完整官方App、真实SDK或实网请求。另有原生parser空body样本，确认失败状态及IDL调用次数为0。没有发送、上传或读取真实账号。

```sh
python3 scripts/fixtures/native_write/generate_client.py \
  --reference-binary /absolute/path/to/accepted/TBClient \
  --fixtures TestSupport/Fixtures/API/Write \
  --verify TestSupport/Fixtures/API/Write/native-ios-client.json
```

原13份fixture保留；该增量可独立核对，无需重复运行未变更的全部回放。Swift组合用例经现有URLSessionHTTPClient和header collector到受控HTTPDataLoading边界，再复用HarnessMockHTTPClient返回合成回包，实际URLSession/网络没有启动。它不提供真实runtime provider、账号持久化、UEG UI、上传或服务端审核证明。
