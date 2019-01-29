# **swift on Windows**
Windows nightlies built on Azure

### Status

| Build | Status |
|:-:|-|
| **Toolchain** | [![Build Status](https://compnerd.visualstudio.com/windows-swift/_apis/build/status/Windows%20Toolchain?branchName=master)](https://compnerd.visualstudio.com/windows-swift/_build/latest?definitionId=1?branchName=master) |
| **Windows SDK** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Windows%20SDK?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=2?branchName=master) |
| **Android SDK** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/android%20SDK?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=4?branchName=master) |

### Getting Started

#### Installing the nightlies

1. Extract the toolchain artifact.  We assume that the toolchain will be installed to `C:\Library`.  Extracting it to that location should give you a hierarchy that looks like `C:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain\usr\bin\swiftc.exe`.
2. In order to develop with this toolchain, you will need an installation of the Windows SDK.  The easiest way to do this is to install Visual Studio.  Additionally, you will need to copy a few files into the SDK to make it usable from swift.
```cmd
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/ucrt.modulemap" -o "%UniversalCRTSdkDir%\Include\%UCRTVersion%\ucrt\module.modulemap"
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/visualc.modulemap" -o "%VCToolsInstallDir%\include\module.modulemap"
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/visualc.apinotes" -o "%VCToolsInstallDir%\include\visualc.apinotes"
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/winsdk.modulemap" -o "%UniversalCRTSdkDir%\Include\%UCRTVersion%\um\module.modulemap"
```
3. You will need to add the ICU libraries for the target.  The nightlies are built against ICU 63.1 from the ICU project.  You can download the binaries for that from http://download.icu-project.org/files/icu4c/63.1/icu4c-63_1-Win64-MSVC2017.zip.  

#### Building swift code

1. The path to the import libraries needs to be added to the `LIB` environment variable.
2. You will need to have the tools in the `PATH` environment variable to use the toolchain.

```cmd
path C:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain\usr\bin;%PATH%
set LIB=%LIB%;C:\Library\Platforms\Windows.platform\Developer\SDKs\Windows.sdk\usr\lib
```

#### Running swift code

The `PATH` environment variable must contain the path to the directory containing the ICU DLLs.

```cmd
path %PATH%;C:\Library\Platforms\Windows.platform\usr\lib
```