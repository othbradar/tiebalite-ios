import com.google.protobuf.DescriptorProtos.FileDescriptorProto;
import com.google.protobuf.DescriptorProtos.FileDescriptorSet;
import com.google.protobuf.Descriptors.Descriptor;
import com.google.protobuf.Descriptors.FieldDescriptor;
import com.google.protobuf.Descriptors.FileDescriptor;
import com.google.protobuf.DynamicMessage;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;

public final class ThreadContentFixtureGenerator {
    private final Map<String, FileDescriptorProto> sourceFiles = new HashMap<>();
    private final Map<String, FileDescriptor> builtFiles = new HashMap<>();

    private ThreadContentFixtureGenerator(FileDescriptorSet descriptorSet) {
        for (FileDescriptorProto file : descriptorSet.getFileList()) {
            sourceFiles.put(file.getName(), file);
        }
    }

    public static void main(String[] arguments) throws Exception {
        if (arguments.length != 2) {
            throw new IllegalArgumentException("usage: descriptor-set output-file");
        }

        FileDescriptorSet descriptorSet = FileDescriptorSet.parseFrom(
            Files.readAllBytes(Path.of(arguments[0]))
        );
        ThreadContentFixtureGenerator generator =
            new ThreadContentFixtureGenerator(descriptorSet);
        generator.buildAllFiles();
        Files.write(Path.of(arguments[1]), generator.makeThread().toByteArray());
    }

    private void buildAllFiles() throws Exception {
        for (String name : sourceFiles.keySet()) {
            buildFile(name);
        }
    }

    private FileDescriptor buildFile(String name) throws Exception {
        FileDescriptor existing = builtFiles.get(name);
        if (existing != null) {
            return existing;
        }

        FileDescriptorProto source = sourceFiles.get(name);
        if (source == null) {
            throw new IllegalStateException("missing descriptor input: " + name);
        }
        FileDescriptor[] dependencies = new FileDescriptor[
            source.getDependencyCount()
        ];
        for (int index = 0; index < source.getDependencyCount(); index++) {
            dependencies[index] = buildFile(source.getDependency(index));
        }
        FileDescriptor built = FileDescriptor.buildFrom(source, dependencies);
        builtFiles.put(name, built);
        return built;
    }

    private Descriptor message(String fullName) {
        for (FileDescriptor file : builtFiles.values()) {
            for (Descriptor descriptor : file.getMessageTypes()) {
                if (descriptor.getFullName().equals(fullName)) {
                    return descriptor;
                }
            }
        }
        throw new IllegalStateException("missing message descriptor: " + fullName);
    }

    private static FieldDescriptor field(Descriptor message, String name) {
        FieldDescriptor field = message.findFieldByName(name);
        if (field == null) {
            throw new IllegalStateException(
                "missing field descriptor: " + message.getFullName() + "." + name
            );
        }
        return field;
    }

    private DynamicMessage.Builder content(int rawType) {
        Descriptor type = message("tieba.PbContent");
        return DynamicMessage.newBuilder(type)
            .setField(field(type, "type"), rawType);
    }

    private DynamicMessage makeThread() {
        Descriptor contentType = message("tieba.PbContent");
        Descriptor memeType = message("tieba.MemeInfo");

        DynamicMessage text = content(0)
            .setField(field(contentType, "text"), "Synthetic alpha\nSynthetic beta")
            .build();
        DynamicMessage legacyText9 = content(9)
            .setField(field(contentType, "text"), "Synthetic type 9")
            .build();
        DynamicMessage legacyText27 = content(27)
            .setField(field(contentType, "text"), "Synthetic type 27")
            .build();
        DynamicMessage legacyText35 = content(35)
            .setField(field(contentType, "text"), "Synthetic type 35")
            .build();
        DynamicMessage legacyText40 = content(40)
            .setField(field(contentType, "text"), "Synthetic type 40")
            .build();

        DynamicMessage safeLink = content(1)
            .setField(field(contentType, "text"), "Synthetic HTTPS link")
            .setField(field(contentType, "link"), "https://fixture.invalid/thread/link")
            .build();
        DynamicMessage unsafeLink = content(1)
            .setField(field(contentType, "text"), "Synthetic blocked link")
            .setField(field(contentType, "link"), "javascript:fixture()")
            .build();
        DynamicMessage emoji = content(2)
            .setField(field(contentType, "text"), "synthetic-emoticon-key")
            .setField(field(contentType, "c"), "synthetic_smile")
            .build();

        DynamicMessage image = content(3)
            .setField(field(contentType, "src"), "https://fixture.invalid/media/source.jpg")
            .setField(field(contentType, "bsize"), "640,480")
            .setField(field(contentType, "bigSrc"), "https://fixture.invalid/media/big.jpg")
            .setField(field(contentType, "cdnSrc"), "https://fixture.invalid/media/cdn.jpg")
            .setField(field(contentType, "bigCdnSrc"), "https://fixture.invalid/media/big-cdn.jpg")
            .setField(field(contentType, "dynamic"), "https://fixture.invalid/media/dynamic.jpg")
            .setField(field(contentType, "originSrc"), "https://fixture.invalid/media/original.jpg")
            .setField(field(contentType, "originSize"), 4096)
            .setField(field(contentType, "isLongPic"), 1)
            .setField(field(contentType, "showOriginalBtn"), 1)
            .setField(field(contentType, "cdnSrcActive"), "https://fixture.invalid/media/active.jpg")
            .build();
        DynamicMessage malformedImage = content(3)
            .setField(field(contentType, "src"), "not a url")
            .setField(field(contentType, "bsize"), "999999999999999999999999,0")
            .build();
        DynamicMessage missingImageFields = content(3).build();

        DynamicMessage mention = content(4)
            .setField(field(contentType, "text"), "@SyntheticMember")
            .setField(field(contentType, "uid"), 7301L)
            .build();
        DynamicMessage missingMentionID = content(4)
            .setField(field(contentType, "text"), "@UnknownMember")
            .build();

        DynamicMessage video = content(5)
            .setField(field(contentType, "text"), "https://fixture.invalid/video/web")
            .setField(field(contentType, "link"), "https://fixture.invalid/video/file.mp4")
            .setField(field(contentType, "src"), "https://fixture.invalid/video/thumbnail.jpg")
            .setField(field(contentType, "bsize"), "1280,720")
            .build();
        DynamicMessage videoThumbnailLink = content(5)
            .setField(field(contentType, "text"), "https://fixture.invalid/video/thumbnail-link")
            .setField(field(contentType, "src"), "https://fixture.invalid/video/thumbnail-only.jpg")
            .setField(field(contentType, "bsize"), "640,360")
            .build();
        DynamicMessage videoLink = content(5)
            .setField(field(contentType, "text"), "https://fixture.invalid/video/fallback")
            .build();
        DynamicMessage voice = content(10)
            .setField(field(contentType, "voiceMD5"), "synthetic-voice-resource")
            .setField(field(contentType, "duringTime"), 17)
            .build();
        DynamicMessage alternateImage = content(20)
            .setField(field(contentType, "src"), "https://fixture.invalid/media/alternate.jpg")
            .setField(field(contentType, "bsize"), "320,240")
            .build();

        DynamicMessage unknown = content(999)
            .setField(field(contentType, "text"), "Synthetic unsupported fallback")
            .setField(field(contentType, "link"), "private:must-not-be-opened")
            .build();
        DynamicMessage meme = DynamicMessage.newBuilder(memeType)
            .setField(field(memeType, "pckId"), 88)
            .setField(field(memeType, "picId"), 9901L)
            .setField(field(memeType, "picUrl"), "https://fixture.invalid/meme/full.png")
            .setField(field(memeType, "thumbnail"), "https://fixture.invalid/meme/thumb.png")
            .setField(field(memeType, "width"), 96)
            .setField(field(memeType, "height"), 96)
            .setField(field(memeType, "detailLink"), "https://fixture.invalid/meme/detail")
            .build();
        DynamicMessage unknownMeme = content(999)
            .setField(field(contentType, "memeInfo"), meme)
            .build();
        DynamicMessage emptyText = content(0).build();
        DynamicMessage trailingText = content(0)
            .setField(field(contentType, "text"), "Synthetic trailing text")
            .build();

        Descriptor optionType = message("tieba.PollOption");
        DynamicMessage firstOption = DynamicMessage.newBuilder(optionType)
            .setField(field(optionType, "id"), 1)
            .setField(field(optionType, "num"), 3L)
            .setField(field(optionType, "text"), "Synthetic option A")
            .build();
        DynamicMessage secondOption = DynamicMessage.newBuilder(optionType)
            .setField(field(optionType, "id"), 2)
            .setField(field(optionType, "num"), 5L)
            .setField(field(optionType, "text"), "Synthetic option B")
            .setField(field(optionType, "image"), "https://fixture.invalid/poll/option-b.png")
            .build();

        Descriptor pollType = message("tieba.PollInfo");
        DynamicMessage poll = DynamicMessage.newBuilder(pollType)
            .setField(field(pollType, "type"), 999)
            .setField(field(pollType, "is_multi"), 1)
            .setField(field(pollType, "total_num"), 8L)
            .setField(field(pollType, "options_count"), 2)
            .setField(field(pollType, "is_polled"), 1)
            .setField(field(pollType, "polled_value"), "2")
            .setField(field(pollType, "tips"), "Synthetic read-only poll")
            .setField(field(pollType, "end_time"), 1700000000)
            .setField(field(pollType, "status"), 999)
            .setField(field(pollType, "title"), "Synthetic poll")
            .setField(field(pollType, "last_time"), 120)
            .addRepeatedField(field(pollType, "options"), firstOption)
            .addRepeatedField(field(pollType, "options"), secondOption)
            .build();

        Descriptor threadType = message("tieba.ThreadInfo");
        DynamicMessage.Builder thread = DynamicMessage.newBuilder(threadType)
            .setField(field(threadType, "id"), 81001L)
            .setField(field(threadType, "threadId"), 81001L)
            .setField(field(threadType, "firstPostId"), 82001L)
            .setField(field(threadType, "title"), "Synthetic thread content fixture")
            .setField(field(threadType, "poll_info"), poll);

        for (DynamicMessage node : new DynamicMessage[] {
            text, legacyText9, legacyText27, legacyText35, legacyText40,
            safeLink, unsafeLink, emoji, image, malformedImage,
            missingImageFields, mention, missingMentionID, video, videoLink,
            videoThumbnailLink,
            voice, alternateImage, unknown, unknownMeme, emptyText, trailingText
        }) {
            thread.addRepeatedField(field(threadType, "firstPostContent"), node);
        }
        return thread.build();
    }
}
