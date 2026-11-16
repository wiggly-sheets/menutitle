// swift-tools-version: 5.9
import Foundation
import PackageDescription

// SwiftPM records the deployment target as the SDK version in the
// `LC_BUILD_VERSION` of the executable, so macOS would treat an app built
// with the 27.2 SDK as a legacy app. Name the real SDK version to the linker:
// the system uses it to decide whether the app gets the current design.
// The Makefile exports the active SDK version. Keep `macOSDeploymentTarget`
// in step with the `platforms` list below.
let macOSDeploymentTarget = "14.0"
let macOSSDKVersion = ProcessInfo.processInfo.environment["MENUTITLE_SDK_VERSION"] ?? "27.2"

let package = Package(
    name: "WindowTitles",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WindowTitles",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-platform_version",
                    "-Xlinker", "macos",
                    "-Xlinker", macOSDeploymentTarget,
                    "-Xlinker", macOSSDKVersion
                ])
            ]
        ),
        .testTarget(name: "WindowTitlesTests", dependencies: ["WindowTitles"]),
    ]
)
