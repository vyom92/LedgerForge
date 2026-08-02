// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "LegacyXLS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LegacyXLS",
            type: .static,
            targets: ["CLegacyXLS"]
        )
    ],
    targets: [
        .target(
            name: "CLegacyXLS",
            path: "Sources/CLegacyXLS",
            sources: [
                "legacy_xls_bridge.c",
                "src/endian.c",
                "src/locale.c",
                "src/ole.c",
                "src/xls.c",
                "src/xlstool.c"
            ],
            publicHeadersPath: "bridge",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("bridge"),
                .headerSearchPath("include")
            ],
            linkerSettings: [
                .linkedLibrary("iconv")
            ]
        )
    ]
)
