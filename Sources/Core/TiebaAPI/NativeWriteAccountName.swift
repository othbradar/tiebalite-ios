/// The iOS profile completion's account-name rule. Inputs must be decoded
/// profile fields, never the UI's fallback display label.
enum NativeWriteAccountName {
    static func updatedName(accountID: String?, currentName: String?, profileID: String?,
                            displayName: String?, loginName: String?) -> String? {
        guard let accountID, let profileID, profileID.utf16.elementsEqual(accountID.utf16) else { return nil }
        let candidate = displayName.flatMap { $0.isEmpty ? nil : $0 } ?? loginName
        guard let candidate, !candidate.isEmpty,
              currentName?.utf16.elementsEqual(candidate.utf16) != true else { return nil }
        return candidate
    }
}
