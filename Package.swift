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
  dependencies: [
    .package(
      url: "https://github.com/sparkle-project/Sparkle",
      exact: "2.9.6"
    ),
  ],
  targets: [
    .target(
      name: "InputMateCore",
      path: "Sources/InputMateCore"
    ),
    .executableTarget(
      name: "InputMate",
      dependencies: [
        "InputMateCore",
        .product(name: "Sparkle", package: "Sparkle"),
      ],
      path: "Sources/InputMate",
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-rpath",
          "-Xlinker", "@executable_path/../Frameworks",
        ])
      ]
    ),
    .executableTarget(
      name: "InputMateTests",
      dependencies: ["InputMateCore"],
      path: "Tests/InputMatePolicyTests"
    ),
  ]
)
