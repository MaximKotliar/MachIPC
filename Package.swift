// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MachIPC",
    products: [
        .library(name: "MachIPC", targets: ["MachIPC"])
    ],
    targets: [
        .target(name: "MachIPC", dependencies: ["DarwinBridge"]),
        .target(name: "DarwinBridge")
    ]
)
