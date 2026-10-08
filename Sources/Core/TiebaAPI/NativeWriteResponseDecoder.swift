import Foundation
import GeneratedProtobuf

/// A decoded native reply, separate from transport success and subsequent UEG UI.
/// Payload metadata alone does not assert that account verification is required.
struct NativeWriteDecodedResponse: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let errorCode: Int32
    let hasPayload: Bool
    let threadID: String
    let postID: String
    let accountAction: NativeWriteResponseRules.AccountAction?
    let category: NativeWriteResponseRules.Category?

    /// TBCServerAPI.parseBodyIsProtobuf changes state to failure only for > 0.
    var serverRejected: Bool { errorCode > 0 }
    var description: String { "NativeWriteDecodedResponse(redacted)" }
    var debugDescription: String { description }

    /// Local correlation guard; it is not the reference's complete UI outcome.
    /// Never fabricate a receipt for missing IDs or another target thread.
    func correlatedReceipt(for target: TextComposeTarget) -> TextWriteReceipt? {
        guard !serverRejected, hasPayload, target.isValid,
              let returnedThreadID = Int64(threadID), returnedThreadID > 0,
              let returnedPostID = Int64(postID), returnedPostID > 0,
              target.kind == .thread || target.threadID == returnedThreadID else { return nil }
        return TextWriteReceipt(threadID: returnedThreadID, postID: returnedPostID)
    }
}

enum NativeWriteResponseDecoder {
    static func decode(_ bytes: Data) throws -> NativeWriteDecodedResponse {
        // Native decode selection comes from requestCMD/x_bd_data_type, not the
        // response MIME. The transport owns HTTP, size and redirect validation.
        let envelope = try TiebaNativeWrite_Response(serializedBytes: bytes)
        let code = envelope.error.errorno
        let payload = envelope.data
        let material = payload.info.hasPassToken ? payload.info.passToken : nil
        return NativeWriteDecodedResponse(
            errorCode: code, hasPayload: envelope.hasData, threadID: payload.tid, postID: payload.pid,
            accountAction: NativeWriteResponseRules.accountAction(
                errorCode: Int64(code), passToken: material),
            category: NativeWriteResponseRules.category(errorCode: Int64(code)))
    }
}
