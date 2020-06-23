# **//swift/build**

## Table of Contents

* [Requirements](#requirements)
* [Installation](#installation)
* [Minimal Hello World (CMake)](#minimal-hello-world--cmake-)

## Requirements

- Windows 10 RedStone 4 (10.0.17763.0) or newer

- Visual Studio 2017 or newer (Visual Studio 2019 recommended)

**Required** Visual Studio Components

| Component | ID |
|-----------|----|
| MSVC v142 - VS 2019 C++ x64/x86 build tools (v14.??) | Microsoft.VisualStudio.Component.VC.Tools.x86.x64 |
| Windows Universal C Runtime | Microsoft.VisualStudio.Component.Windows10SDK |
| Windows 10 SDK (10.0.17763.0)<sup>[1](#windows-sdk)</sup> | Microsoft.VisualStudio.Component.Windows10SDK.17763 |

<sup><a name="windows-sdk">1</a></sup> You may install a newer SDK if you desire. 17763 is listed here to match the minimum Windows release supported.

**Recommended** Visual Studio Components

| Component | ID |
|-----------|----|
| C++ CMake tools for Windows<sup>[1](#windows-cmake)</sup> | Microsoft.VisualStudio.Component.VC.CMake.Project |
| Git for Windows<sup>[2](#windows-git)</sup> | Microsoft.VisualStudio.Component.Git |
| Python 3 64-bit (3.7.5)<sup>[3](#windows-python)</sup> | Component.CPython.x64 |

<sup><a name="windows-cmake">1</a></sup> Provides `ninja` which is needed for building projects. You may download it from [ninja-build](https://github.com/ninja-build/ninja) instead.<br/>
<sup><a name="windows-git">2</a></sup> Provides `git` to clone projects from GitHub. You may download it from [git-scm](https://git-scm.com/) instead.<br/>
<sup><a name="windows-python">3</a></sup> Provides `python` needed for Python integration. You may download it from [python](https://www.python.org/) instead.<br/>

## Installation

1. Install Visual Studio from [Microsoft](https://visualstudio.microsoft.com).
2. Install Swift Toolchain from [//swift/build](https://compnerd.visualstudio.com/swift-build).
3. Deploy Windows SDK updates.  This must be run from an (elevated) "Administrator" `x64 Native Tools for VS2019 Command Prompt` shell.

```cmd
set SDKROOT=%SystemDrive%\Library\Developer\Platforms\Windows.platform\Developer\SDKs\Windows.sdk
copy "%SDKROOT%\usr\share\ucrt.modulemap" "%UniversalCRTSdkDir%\Include\%UCRTVersion%\ucrt\module.modulemap"
copy "%SDKROOT%\usr\share\visualc.modulemap" "%VCToolsInstallDir%\include\module.modulemap"
copy "%SDKROOT%\usr\share\visualc.apinotes" "%VCToolsInstallDir%\include\visualc.apinotes"
copy "%SDKROOT%\usr\share\winsdk.modulemap" "%UniversalCRTSdkDir%\Include\%UCRTVersion%\um\module.modulemap"
```

**NOTE**: this will be need to be re-run every time Visual Studio is updated.

## Minimal Hello World (CMake)

Currently the only supported way to build is CMake with the Ninja generator.

This example walks through building an example Swift program from the CMake Swift examples at [swift-build-examples](https://github.com/compnerd/swift-build-examples).

1. Clone the sources

```cmd
git clone git://github.com/compnerd/swift-build-examples /SourceCache/swift-build-examples
```

2. Setup Common Build Parameter Variables

```cmd
set SDKROOT=%SystemDrive%/Library/Developer/Platforms/Windows.platform/Developer/SDKs/Windows.sdk
set SWIFTFLAGS=-sdk %SDKROOT% -I %SDKROOT%/usr/lib/swift -L %SDKROOT%/usr/lib/swift/windows
```

3. Configure

```cmd
"%ProgramFiles%/CMake/bin/cmake.exe"  ^
  -B /BinaryCache/HelloWorld          ^
  -D BUILD_SHARED_LIBS=YES            ^
  -D CMAKE_BUILD_TYPE=Release         ^
  -D CMAKE_Swift_FLAGS="%SWIFTFLAGS%" ^
  -G Ninja                            ^
  -S /SourceCache/swift-build-examples/HelloWorld-CMake
```

4. Build

```cmd
cmake --build /BinaryCache/HelloWorld
```
