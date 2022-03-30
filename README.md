# **//swift/build**

The `//swift/build` project provides a CI configuration for [Azure 
Pipelines](https://azure.microsoft.com/en-us/services/devops/pipelines/) that allows 
building Swift for multiple platforms. The configuration is not specific to Azure, 
and can be reused for developer builds as well. Thanks to modular packaging, with 
`//swift/build` you can easily cross-compile your Swift code for Android and Windows 
targets, or build on Windows natively without cross-compilation.

## Table of Contents

- [**//swift/build**](#--swift-build---)
  * [Getting Started (Docker)](docs/GettingStartedDocker.md)
  * [Getting Started (Native)](docs/GettingStartedWindows.md)
  * [Status](#status)
  * [Getting the latest build](#Getting-the-latest-build)

## Status

### Active Builds

| Build | Status |
| :-: | --- |
| **VS2022 (main)** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/VS2022?repoName=compnerd%2Fswift-build&branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=65&repoName=compnerd%2Fswift-build&branchName=master) |
| **VS2019 (main)** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/VS2019?repoName=compnerd%2Fswift-build&branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=7&repoName=compnerd%2Fswift-build&branchName=master) |
| **VS2019 (Swift 5.6)** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/VS2019%205.6?repoName=compnerd%2Fswift-build&branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=64&repoName=compnerd%2Fswift-build&branchName=master) |
| **VS2019 (Swift 5.5)** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/VS2019%205.5?repoName=compnerd%2Fswift-build&branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=61&repoName=compnerd%2Fswift-build&branchName=master) |
| **VS2019 (Swift 5.4)** | [![Build Status](https://dev.azure.com/compnerd/swift-build/_apis/build/status/VS2019%205.4?repoName=compnerd%2Fswift-build&branchName=master)](https://dev.azure.com/compnerd/swift-build/_build/latest?definitionId=59&repoName=compnerd%2Fswift-build&branchName=master) |

### Pre-release builds

- Unified VS2019 Swift 5.6
- Unified VS2019 Swift 5.5

### Retired Builds

- VS2017 (main)
- VS2019 (Swift 5.3)
- VS2019 (Swift 5.2)
- VS2017 (Swift 5.2)

## Getting the latest build

### Stable builds
The latest stable build can be acuqired from the Swift [downloads](https://download.swift.org).

### Development builds
The `utilities/swift-build.py` script allows downloading of the latest build artifacts. The script requires the `azure-devops` and `tabulate` python packages. These can be installed with `pip`:
```
python3 -m pip install tabulate azure-devops
```

For example, to download the latest VS2019 build:
```
swift-build.py --download --build-id VS2019 --latest-artifacts --filter installer.exe
```
