enum UserProfileState: Equatable, Sendable {
    case idle(UserProfileRoute)
    case loading(UserProfileRoute)
    case loaded(UserProfile)
    case empty(UserProfileRoute)
    case failed(UserProfileRoute)
}
