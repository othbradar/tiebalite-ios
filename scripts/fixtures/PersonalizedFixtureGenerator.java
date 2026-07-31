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

public final class PersonalizedFixtureGenerator {
    private final Map<String, FileDescriptorProto> sourceFiles = new HashMap<>();
    private final Map<String, FileDescriptor> builtFiles = new HashMap<>();

    private PersonalizedFixtureGenerator(FileDescriptorSet descriptorSet) {
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
        PersonalizedFixtureGenerator generator =
            new PersonalizedFixtureGenerator(descriptorSet);
        generator.buildAllFiles();
        Files.write(Path.of(arguments[1]), generator.makeResponse().toByteArray());
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

    private DynamicMessage makeResponse() {
        Descriptor userType = message("tieba.User");
        DynamicMessage author = DynamicMessage.newBuilder(userType)
            .setField(field(userType, "id"), 7001L)
            .setField(field(userType, "name"), "fixture_author")
            .setField(field(userType, "nameShow"), "Fixture Author")
            .setField(field(userType, "portrait"), "fixture-portrait-7001")
            .build();

        Descriptor threadType = message("tieba.ThreadInfo");
        DynamicMessage firstThread = DynamicMessage.newBuilder(threadType)
            .setField(field(threadType, "id"), 1001L)
            .setField(field(threadType, "threadId"), 2001L)
            .setField(field(threadType, "title"), "Fixture recommendation")
            .setField(field(threadType, "replyNum"), 12)
            .setField(field(threadType, "viewNum"), 345)
            .setField(field(threadType, "lastTimeInt"), 1700000000)
            .setField(field(threadType, "threadTypes"), 1)
            .setField(field(threadType, "isGood"), 1)
            .setField(field(threadType, "author"), author)
            .setField(field(threadType, "forumId"), 5001L)
            .setField(field(threadType, "forumName"), "fixture_forum")
            .setField(field(threadType, "firstPostId"), 3001L)
            .setField(field(threadType, "post_id"), 3001L)
            .setField(field(threadType, "authorId"), 7001L)
            .build();

        Descriptor videoType = message("tieba.VideoInfo");
        DynamicMessage emptyVideo = DynamicMessage.newBuilder(videoType).build();
        DynamicMessage secondThread = DynamicMessage.newBuilder(threadType)
            .setField(field(threadType, "id"), 1002L)
            .setField(field(threadType, "threadId"), 2002L)
            .setField(field(threadType, "isNoTitle"), 1)
            .setField(field(threadType, "threadTypes"), 999)
            .setField(field(threadType, "forumId"), 5002L)
            .setField(
                field(threadType, "forumName"),
                "fixture_forum_missing_author"
            )
            .setField(field(threadType, "videoInfo"), emptyVideo)
            .build();

        Descriptor metadataType = message("tieba.ThreadPersonalized");
        DynamicMessage metadata = DynamicMessage.newBuilder(metadataType)
            .setField(field(metadataType, "tid"), 1001L)
            .setField(field(metadataType, "weight"), "fixture-weight")
            .setField(field(metadataType, "source"), "fixture-source")
            .setField(field(metadataType, "extra"), "fixture-extra")
            .build();

        Descriptor dataType = message("tieba.PersonalizedResponseData");
        DynamicMessage responseData = DynamicMessage.newBuilder(dataType)
            .addRepeatedField(field(dataType, "thread_list"), firstThread)
            .addRepeatedField(field(dataType, "thread_list"), secondThread)
            .addRepeatedField(
                field(dataType, "thread_personalized"),
                metadata
            )
            .build();

        Descriptor errorType = message("tieba.Error");
        DynamicMessage success = DynamicMessage.newBuilder(errorType).build();
        Descriptor responseType = message("tieba.PersonalizedResponse");
        return DynamicMessage.newBuilder(responseType)
            .setField(field(responseType, "error"), success)
            .setField(field(responseType, "data"), responseData)
            .build();
    }
}
