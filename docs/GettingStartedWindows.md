# **//swift/build**

## Table of Contents

* [Requirements](#requirements)
* [Installation](#installation)
* [Minimal Hello World (CMake)](#minimal-hello-world--cmake-)

## Requirements

- Windows 10 RedStone 5 (10.0.17763.0) or newer

- Visual Studio 2017 or newer (Visual Studio 2019 recommended)

**Required** Visual Studio Components

| Component | ID |
|-----------|----|
| MSVC v142 - VS 2019 C++ x64/x86 build tools (v14.25)<sup>[1](#visual-c)</sup> | Microsoft.VisualStudio.Component.VC.Tools.x86.x64 |
| Windows Universal C Runtime | Microsoft.VisualStudio.Component.Windows10SDK |
| Windows 10 SDK (10.0.17763.0)<sup>[2](#windows-sdk)</sup> | Microsoft.VisualStudio.Component.Windows10SDK.17763 |

<sup><a name="visual-c">1</a></sup> This is needed for the Visual C++ headers (you can use `-use-ld=lld` to use `lld` instead of `link.exe`)<br/>
<sup><a name="windows-sdk">2</a></sup> You may install a newer SDK if you desire. 17763 is listed here to match the minimum Windows release supported.

**Recommended** Visual Studio Components

| Component | ID |
|-----------|----|
| Git for Windows<sup>[1](#windows-git)</sup> | Microsoft.VisualStudio.Component.Git |
| Python 3 64-bit (3.7.5)<sup>[2](#windows-python)</sup> | Component.CPython.x64 |

<sup><a name="windows-git">1</a></sup> Provides `git` to clone projects from GitHub. You may download it from [git-scm](https://git-scm.com/) instead.<br/>
<sup><a name="windows-python">2</a></sup> Provides `python` needed for Python integration. You may download it from [python](https://www.python.org/) instead.<br/>

**Suggested** Visual Studio Components

| Component | ID |
|-----------|----|
| C++ CMake tools for Windows<sup>[1](#windows-cmake)</sup> | Microsoft.VisualStudio.Component.VC.CMake.Project |

<sup><a name="windows-cmake">1</a></sup> Provides `ninja` which is needed for building projects. You may download it from [ninja-build](https://github.com/ninja-build/ninja) instead.<br/>

## Installation

1. Install Visual Studio from [Microsoft](https://visualstudio.microsoft.com).
2. Install Swift Toolchain from [//swift/build](https://compnerd.visualstudio.com/swift-build).
3. Deploy Windows SDK, Visual C++ updates.  This must be run from an (elevated) "Administrator" `x64 Native Tools for VS2019 Command Prompt` shell.

```cmd
:: Swift 5.3 and earlier require that you set `SDKROOT` to the correct value.
:: set SDKROOT=%SystemDrive%\Library\Developer\Platforms\Windows.platform\Developer\SDKs\Windows.sdk
copy "%SDKROOT%\usr\share\ucrt.modulemap" "%UniversalCRTSdkDir%\Include\%UCRTVersion%\ucrt\module.modulemap"
copy "%SDKROOT%\usr\share\visualc.modulemap" "%VCToolsInstallDir%\include\module.modulemap"
copy "%SDKROOT%\usr\share\visualc.apinotes" "%VCToolsInstallDir%\include\visualc.apinotes"
copy "%SDKROOT%\usr\share\winsdk.modulemap" "%UniversalCRTSdkDir%\Include\%UCRTVersion%\um\module.modulemap"
```

**NOTE**: this will be need to be re-run every time Visual Studio is updated.

## Minimal Hello World (CMake)

Currently the only supported way to build is CMake with the Ninja generator.

This example walks through building an example Swift program from the CMake Swift examples at [swift-cmake-examples](https://github.com/compnerd/swift-cmake-examples).

1. Clone the sources

```cmd
git clone git://github.com/compnerd/swift-build-examples %SystemDrive%/SourceCache/swift-build-examples
```

2. Setup Common Build Parameter Variables

```cmd
:: Swift 5.3 and earlier require that you set `SDKROOT` to the correct value.
:: set SDKROOT=%SystemDrive%/Library/Developer/Platforms/Windows.platform/Developer/SDKs/Windows.sdk
set SWIFTFLAGS=-sdk %SDKROOT% -resource-dir %SDKROOT%/usr/lib/swift -I %SDKROOT%/usr/lib/swift -L %SDKROOT%/usr/lib/swift/windows
```

3. Configure

```cmd
"%ProgramFiles%/CMake/bin/cmake.exe"      ^
  -B %SystemDrive%/BinaryCache/HelloWorld ^
  -D BUILD_SHARED_LIBS=YES                ^
  -D CMAKE_BUILD_TYPE=Release             ^
  -D CMAKE_Swift_FLAGS="%SWIFTFLAGS%"     ^
  -G Ninja                                ^
  -S %SystemDrive%/SourceCache/swift-build-examples/HelloWorld-CMake
```

4. Build

```cmd
cmake --build %SystemDrive%/BinaryCache/HelloWorld
```
