// swift-tools-version: 5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
     name: "Lantern",
     platforms: [
        // Minimum platform version
         .iOS(.v13)
     ],
     products: [
         .library(
             name: "Liblantern",
             targets: ["Liblantern"]),
     ],
     dependencies: [
         // No dependencies
     ],
     targets: [
        .binaryTarget(
            name: "Liblantern",
            path: "../Frameworks/Liblantern.xcframework"
        )
     ]
 )
