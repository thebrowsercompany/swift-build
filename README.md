# **//swift/build**

## Table of Contents

- [**//swift/build**](#--swift-build---)
  * [Getting Started (Docker)](docs/GettingStartedDocker.md)
  * [Getting Started (Native)](docs/GettingStartedWindows.md)
  * [Status](#status)

## Status

**Dependencies**

| Build | Status |
| :-: | --- |
| **CURL** | [![Build Status](https://compnerd.visualstudio.com/swift-build/_apis/build/status/CURL?branchName=master)](https://compnerd.visualstudio.com/swift-build/_build/latest?definitionId=11&branchName=master) |
| **ICU** | [![Build Status](https://compnerd.visualstudio.com/swift-build/_apis/build/status/ICU?branchName=master)](https://compnerd.visualstudio.com/swift-build/_build/latest?definitionId=9&branchName=master) |
| **SQLite3** | [![Build Status](https://compnerd.visualstudio.com/swift-build/_apis/build/status/SQLite?branchName=master)](https://compnerd.visualstudio.com/swift-build/_build/latest?definitionId=12&branchName=master) |
| **TensorFlow** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/tensorflow?branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=44&branchName=master) |
| **XML2** | [![Build Status](https://compnerd.visualstudio.com/swift-build/_apis/build/status/XML2?branchName=master)](https://compnerd.visualstudio.com/swift-build/_build/latest?definitionId=10&branchName=master) |
| **ZLIB** | [![Build Status](https://compnerd.visualstudio.com/swift-build/_apis/build/status/zlib?branchName=master)](https://compnerd.visualstudio.com/swift-build/_build/latest?definitionId=16&branchName=master) |

**Swift 5.2**

| Build | Status |
| :-: | --- |
| **VS2019** | [![Build Status](https://compnerd.visualstudio.com/swift-build/_apis/build/status/VS2019%20Swift%205.2?branchName=master)](https://compnerd.visualstudio.com/swift-build/_build/latest?definitionId=43&branchName=master) |

<details>
  <summary>Build Contents</summary>

  - **VS2019**
    - *Toolchain (llvm, clang, lld, lldb, swift)*
      - ARM64
      - x64
    - *Swift SDK for Android (swift, libdispatch, foundation, xctest)*
      - ARM
      - ARM64
      - x64
      - x86
    - *Swift SDK for Windows (swift, libdispatch, foundation, xctest)*
      - ARM
      - ARM64
      - x64
      - x86
 </details>

**Swift 5.3**

| Build | Status |
| :-: | --- |
| **VS2019** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/VS2019%205.3?branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=53&branchName=master) |

**Swift HEAD (Development)**

| Build | Status |
| :-: | --- |
| **macOS** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/macOS?branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=15&branchName=master) |
| **VS2017** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/VS2017?branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=1&branchName=master) |
| **VS2019** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/VS2019?branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=7&branchName=master) |
| **VS2017 (Facebook)** | [![Build Status](https://compnerd.visualstudio.com/swift-build/_apis/build/status/VS2017%20Swift%20(Facebook)?branchName=master)](https://compnerd.visualstudio.com/swift-build/_build/latest?definitionId=5&branchName=master) |
| **VS2019 (Facebook)** | [![Build Status](https://compnerd.visualstudio.com/swift-build/_apis/build/status/VS2019%20Swift%20(Facebook)?branchName=master)](https://compnerd.visualstudio.com/swift-build/_build/latest?definitionId=31&branchName=master) |
| **Ubuntu 18.04 (flowkey)** | [![Build Status](https://compnerd.visualstudio.com/swift-build/_apis/build/status/Ubuntu%2018.04%20(flowkey)?branchName=master)](https://compnerd.visualstudio.com/swift-build/_build/latest?definitionId=14&branchName=master) |
| **macOS (TensorFlow)** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/macOS%20Swift%20TensorFlow?branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=47&branchName=master) |
| **VS2019 (TensorFlow)**| [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/VS2019%20Swift%20TensorFlow%20(Google)?branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=46&branchName=master) |

<details>
  <summary>Build Contents</summary>

  - **macOS**
    - *Toolchain (llvm, clang, lld, lldb, swift)*
      - x64
    - *xctoolchain*
      - x64

  - **VS2017**
    - *Toolchain (llvm, clang, lld, lldb, swift)*
      - x64
  
  - **VS2019**
    - *Toolchain (llvm, clang, lld, lldb, swift)*
      - ARM64
      - x86
    - *Swift SDK for Android (swift, libdispatch, foundation, xctest)*
      - ARM
      - ARM64
      - x64
      - x86
    - *Swift SDK for Windows (swift, libdispatch, foundation, xctest)*
      - ARM
      - ARM64
      - x64
      - x86
    - *Swift Developer Tools (llbuild)*
      - ARM64
      - x64
    - *MSI*
      - Toolchain
        - x64

  - **VS2017 (Facebook)**
    - *Toolchain (llvm, clang, lld, lldb, swift)*
      - X64
    - *Swift SDK for Windows (swift, libdispatch, foundation, xctest)*
      - ARM
      - ARM64
      - x64
      - x86

  - **VS2019 (Facebook)**
    - *Toolchain (llvm, clang, lld, lldb, swift)*
      - x64
    - *Swift SDK for Windows (libdispatch, foundation, xctest)*
      - ARM
      - ARM64
      - x64
      - x86

  - **Ubuntu 18.04 (flowkey)**
    - *Toolchain (llvm, clang, lld, lldb, swift)*
      - x64
    - *Swift SDK for Linux (swift, libdispatch, foundation, xctest)*
      - x64
    - *Swift Developer Tools (llbuild, swift-package-manager)*
      - x64
    - *debian packages*
      - toolchain
        - x64
      - ICU
        - x64
      - Developer Tools
        - x64
      - SDK
        - Linux
</details>
