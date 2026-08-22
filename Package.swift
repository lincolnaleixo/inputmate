// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "InputMate",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "InputMate", targets: ["InputMate"]),
    .executable(name: "InputMateTests", targets: ["InputMateTests"]),
  ],
  targets: [
    .target(
      name: "InputMateCore",
      path: "Sources/InputMateCore"
    ),
    .executableTarget(
      name: "InputMate",
      dependencies: ["InputMateCore"],
      path: "Sources/InputMate"
    ),
    .executableTarget(
      name: "InputMateTests",
      dependencies: ["InputMateCore"],
      path: "Tests/InputMatePolicyTests"
    ),
  ]
)
