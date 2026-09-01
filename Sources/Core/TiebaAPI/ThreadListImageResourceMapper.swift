enum ThreadListImageResourceMapper {
    static func map(
        bigPicture: String,
        dynamicPicture: String,
        sourcePicture: String,
        originalPicture: String,
        ownerResourceID: String
    ) -> ImageResourceDescriptor? {
        let resource = ImageResourceDescriptor(
            resourceID: ownerResourceID,
            candidateURLs: [
                bigPicture,
                dynamicPicture,
                sourcePicture,
                originalPicture
            ]
        )
        return resource.isNetworkLoadable ? resource : nil
    }
}
