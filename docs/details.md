# Swift Toolchain & Platform SDK

## *Nomenclature*

Different terms are used to reference the different portions of the tree.  These help identify the various uses for the content in the tree.

- **Runtime** (`/Library/Swift`, `/Library/ICU-64.2`, ...)

  This is the *runtime* component.  These are the libraries which are needed by the user to run Swift content.  These set of libraries are required to be redistributed with any Swift application or must be provided by the Operating System (e.g. as with macOS).  This usually contains the Swift runtime, standard library (and its dependency, ICU).  It may optionally require libdispatch and Foundation (and its dependency, ICU; the remainder of the dependencies are statically linked currently) if they are used by the application.  Ideally, they are installed into versioned directories so that different versions of the libraries are available for different applications.  Only one copy of the runtime component is needed, although each application may require different portions of it.
  
- **SDK** (`/Library/Platforms/Windows.platform/...`, ...)

  More than one SDK may be installed at a time.  Currently, the builds at https://compnerd.visualstudio.com/windows-swift provide SDKs for Windows, Android, and Linux.  There is work under way to enable multiple parallel architectures in a single platform SDK, but until such time as that is merged into the tree, only a single architecture, platform combination can be supported by a single SDK.  Permitting the SDK to be relocated enables SDKs to be swapped out during development to target different architectures.  This content is only needed by the developer to build products for the platform, architecture combination.
  
  The platform SDK also contains target developer content such as XCTest.  This allows the use of XCTest to build tests which run on the architecture, platform combination of the SDK.
  
 - **Toolchain** (`/Library/Developer/Toolchains/unknown-Asserts-development.xctoolchain/...`, ...)
 
   More than one toolchain may be installed at a time.  Currently, the builds at https://compnerd.visualstudio.com/windows-swift only provide a single toolchain.  The toolchains are named as `[vendor]-[Asserts|NoAsserts]-[version].xctoolchain`.  This allows for installing multiple versions of the toolchain in parallel and easily switching between them.  The toolchain contains all the tools required to build C, C++, and Swift code (compiler, assembler, linker) as well as to debug the products (lldb).  Additionally, it contains tools to inspect the binaries (e.g. `objdump`).  This allows a single installation of the toolchain to be sufficient to build most applications and their dependencies.
  
   The toolchain distributed by the builds at https://compnerd.visualstudio.com/windows-swift (unofficially marked as having the vendor `dt.compnerd.org`), are designed to be used for cross-compilation for a variety of targets.  They support Windows, Linux, and Darwin targets at least, and support ARM, ARM64, X86, X64 architectures.  Additional architectures may be added in the future.

- **Developer Tools** (`/Library/Developer/SharedSupport/...`, ...)

   A single copy of the developer tools can be installed a time.  This contains items such as llbuild, swift-package-manager, etc.  These tools are only available on the supported development platforms (`Windows-x86_64`, `Linux-x86_64`, `macOS-x86_64`).

## *Tree Structure*

The structure of the system is heavily inspired by the layout of Xcode and the bundle model on Darwin platforms.

This structure enables the full tree to be easily relocated.  Although the recommended manner of installation is MSIs, the ability to easily move the installation around is extremely helpful in the case of constructing the image and testing multiple versions in parallel.

This abbreviated tree serves as a reference for the layout.

```
Library
  ├ Developer
  │ ├ Toolchains
  │ │ └ unknown-Asserts-development.xctoolchain
  │ │   └ usr
  │ │     ├ bin
  │ │     │ ├ clang
  │ │     │ ├ ...
  │ │     │ └ swift
  │ │     └ lib
  │ │       ├ clang
  | |       │ └ ...
  │ │       └ swift
  │ │         └ windows
  │ │           └ x86_64
  │ │             ├ ...
  │ │             ├ Swift.swiftdoc
  │ │             ├ Swift.swiftinterface
  │ │             └ Swift.swiftmodule
  │ └ Platforms
  │   └ Windows.platform
  │     └ Developer
  │       ├ Library
  |       | └ XCTest-development
  |       |   └ usr
  |       |     └ bin
  |       |       └ XCTest.dll
  │       └ SDKs
  │         └ Windows.sdk
  │           └ usr
  │             └ bin
  │               ├ ...
  │               └ swiftWinSDK.dll
  ├ ICU-64.2
  └ Swift
```

The top level library simply serves as the root.  It is a collection of various items.  The nomenclature for the various pieces is explained below.

## Installation Recommendations

On Windows, the suggested distribution mechanism is via MSI.  This allows management of large scale deployments via SCCM (System Center Configuration Manager) and scales to individual installation as well.  The installation can be scripted or run through the regular UI.
