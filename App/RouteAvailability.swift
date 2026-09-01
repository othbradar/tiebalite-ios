@MainActor
func openComponentGalleryIfAvailable(
    using navigation: AppNavigationStore
) {
#if DEBUG
    navigation.openSettingsRoute(.componentGallery)
#endif
}
