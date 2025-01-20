load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

sgDeps = [
    "//Swiftgram/SGSimpleSettings:SGSimpleSettings",
    "//Swiftgram/SGInputToolbar:SGInputToolbar"
]

swift_library(
    name = "LegacyMessageInputPanel",
    module_name = "LegacyMessageInputPanel",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = sgDeps + [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/AccountContext",
        "//submodules/LegacyComponents",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/ContextUI",
        "//submodules/TooltipUI",
        "//submodules/UndoUI",
        "//submodules/TelegramUI/Components/MessageInputPanelComponent",
        "//submodules/TelegramUI/Components/LegacyMessageInputPanelInputView",
        "//submodules/TelegramNotices",
    ],
    visibility = [
        "//visibility:public",
    ],
)
