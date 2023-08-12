# **//swift/build**

## Table of Contents

* [Requirements](#requirements)
* [Installation](#installation)

## Requirements

- Windows 10 RedStone 5 (10.0.17763.0) or newer

- Visual Studio 2017 or newer (Visual Studio 2022 recommended)

**Required** Visual Studio Components

| Component | ID |
|-----------|----|
| MSVC v142 - VS 2019 C++ x64/x86 build tools (v14.25)<sup>[1](#visual-c)</sup> | Microsoft.VisualStudio.Component.VC.Tools.x86.x64 |
| Windows 10 SDK (10.0.17763.0)<sup>[2](#windows-sdk)</sup> | Microsoft.VisualStudio.Component.Windows10SDK.17763 |

<sup><a name="visual-c">1</a></sup> This is needed for the Visual C++ headers (you can use `-use-ld=lld` to use `lld` instead of `link.exe`)<br/>
<sup><a name="windows-sdk">2</a></sup> You may install a newer SDK if you desire. 17763 is listed here to match the minimum Windows release supported.

**Recommended** Visual Studio Components

| Component | ID |
|-----------|----|
| Git for Windows<sup>[1](#windows-git)</sup> | Microsoft.VisualStudio.Component.Git |

<sup><a name="windows-git">1</a></sup> Provides `git` needed for the [Swift Package Manager](https://github.com/apple/swift-package-manager). You may download it from [git-scm](https://git-scm.com/) instead.<br/>

**Recommended** Dependencies

| Dependency |
| Python 3 64-bit (3.9.10)<sup>[2](#windows-python)</sup> |

<sup><a name="windows-python">2</a></sup> Provides `python` needed for LLDB.<br/>

## Installation

1. Install Visual Studio from [Microsoft](https://visualstudio.microsoft.com).
2. Install Swift Toolchain from [//swift/build](https://compnerd.visualstudio.com/swift-build).
