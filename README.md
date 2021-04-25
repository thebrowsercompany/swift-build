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

## Getting the latest build

### Stable builds
The latest stable build can be acuqired from the [releases](https://github.com/compnerd/swift-build/releases) page.

### Development builds
The `utilities/swift-build.py` script allows downloading of the latest build artifacts. The script requires the `azure-devops` and `tabulate` python packages. These can be installed with `pip`:
```
python3 -m pip install tabulate azure-devops
```

For example, to download the latest VS2019 build:
```
swift-build.py --download --build-id VS2019 --latest-artifacts --filter installer.exe
```
