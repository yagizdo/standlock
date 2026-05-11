// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "StandLockKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "StandLockCore", targets: ["StandLockCore"]),
        .library(name: "Scheduling", targets: ["Scheduling"]),
        .library(name: "Detection", targets: ["Detection"]),
        .library(name: "Locking", targets: ["Locking"]),
        .library(name: "Coordination", targets: ["Coordination"]),
    ],
    targets: [
        .target(name: "StandLockCore"),
        .target(name: "Scheduling", dependencies: ["StandLockCore"]),
        .target(name: "Detection", dependencies: ["StandLockCore"]),
        .target(name: "Locking", dependencies: ["StandLockCore"]),
        .target(name: "Coordination", dependencies: [
            "StandLockCore", "Scheduling", "Detection", "Locking",
        ]),
        .testTarget(name: "StandLockCoreTests", dependencies: ["StandLockCore"]),
        .testTarget(name: "SchedulingTests", dependencies: ["Scheduling"]),
        .testTarget(name: "DetectionTests", dependencies: ["Detection"]),
        .testTarget(name: "LockingTests", dependencies: ["Locking"]),
        .testTarget(name: "CoordinationTests", dependencies: ["Coordination", "StandLockCore"]),
    ]
)
