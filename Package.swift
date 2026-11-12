// swift-tools-version: 5.9

// Kochbuch to Go – App Playground
// Öffnen mit Xcode 15+ (Mac) oder Swift Playgrounds 4.4+ (iPad oder Mac).

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Kochbuch to Go",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Kochbuch to Go",
            targets: ["AppModule"],
            bundleIdentifier: "de.kochbuchtogo.app",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.green),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
