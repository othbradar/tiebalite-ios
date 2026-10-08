/// Evidence-backed native error predicates. This does not decide that a write
/// succeeded, execute verification, change the account, or automatically retry.
enum NativeWriteResponseRules {
    enum AccountAction: String, Hashable, Sendable {
        case reauthenticate, bindMobile, verifyIdentity, changePassword, verifyFace
    }

    enum Category: String, Sendable {
        case sms, forbidden, realName, captcha, antiAbuse, illegalWords
        case postingFrequency, muted, appealing, forumMCNRestriction
    }

    static func accountAction(errorCode: Int64, passToken: String?) -> AccountAction? {
        switch errorCode {
        case 1: .reauthenticate
        case 3_250_017: .bindMobile
        case 3_250_020, 3_250_021: passToken?.isEmpty == false ? .verifyIdentity : nil
        case 3_250_022: .changePassword
        case 3_250_023: .verifyFace
        default: nil
        }
    }

    /// These scalar predicates are separate from account-action precedence and
    /// model-specific UEG handling. Unknown codes remain unclassified.
    static func category(errorCode: Int64) -> Category? {
        switch errorCode {
        case 5, 6: .captcha
        case 3_250_012: .sms
        case 3_250_001...3_250_004: .forbidden
        case 1_990_055: .realName
        case 227_001: .antiAbuse
        case 220_015: .illegalWords
        case 220_034: .postingFrequency
        case 230_277: .muted
        case 3_250_013: .appealing
        case 1_211_067: .forumMCNRestriction
        default: nil
        }
    }
}
