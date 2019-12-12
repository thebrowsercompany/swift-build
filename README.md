# **Swift on Windows (& more)**

![](images/windows-swift.jpg)

## Table of Contents

- [**Swift on Windows (& more)**](#--swift-on-windows----more---)
  * [Getting Started](#getting-started)
    + [Hello World (CMake)](#hello-world--cmake-)
    + [Windows](#windows)
  * [Status](#status)

## Getting Started

Getting started is as simple as running a command from your shell:
```Shell
$ docker run --rm --publish 127.0.0.1:8080:8080 --volume $HOME/projects/myproject:/SourceCache/myproject --volume $HOME/projects/bin/myproject:/BinaryCache/myproject compnerd/swift:latest
```

* The docker image doesn't require persistent state, so we use `--rm` to automatically clean up and remove the container when it exits.
* Visual Studio Code is exposed over a web interface on port 8080. We publish this port via `--publish 127.0.0.1:8080:8080` <sup>[\*](#footnote1)</sup>.
* `--volume $HOME/projects/myproject:/SourceCache/myproject` and `--volume $HOME/projects/bin/myproject:/BinaryCache/myproject` mount your source tree for "myproject" into the docker image as a subdirectory of `/SourceCache` and the directory for compiled output into it as `/BinaryCache`.
* `compnerd/swift` references the latest tag on [Docker Hub](https://hub.docker.com/r/compnerd/swift).

<a name="footnote1">\*</a> If you'd like to access this from anywhere other than localhost, you can replace this with `--publish 0.0.0.0:8080:8080`, but no authentication or HTTPS are configured, so doing this with no additional configuration will be insecure.

### Minimal Hello World (CMake)

First, clone the examples repository:

```Shell
$ git clone https://github.com/compnerd/swift-windows-examples.git
```

Next, make a directory for the binary output (remember to substitute your own path!):
```Shell
$ mkdir -p $HOME/bin/HelloMinimal-CMake
```

Next start up the build environment:

```Shell
$ docker run --rm --publish 127.0.0.1:8080:8080 --volume /path/to/swift-windows-examples/HelloMinimal-CMake:/SourceCache/HelloMinimal-CMake --volume $HOME/bin/HelloMinimal-CMake:/BinaryCache/HelloMinimal-CMake compnerd/swift:latest
```

Navigate to localhost in your browser: http://127.0.0.1:8080/. Or, if you want to open a workspace directly, you can provide a path: http://localhost:8080/?folder=/SourceCache/HelloMinimal-CMake

Visual Studio Code will prompt you to configure your project with CMake - choose "Yes".

!["Configure this Project" dialog](images/GettingStarted/configure-this-project.png)

You will be offered a selection of CMake Kits. This dictates the target system that this session will build. For this example, select "Linux x86_64".

![CMake Kit selection](images/GettingStarted/select-kit.png)

You may be asked whether Visual Studio Code should always configure CMake projects upon opening. You can choose either "Yes" or "For this Workspace"; all this does is add a setting to `.vscode/settings.json`. Because we run a fresh image on each run of the docker container, You will need to click "Yes" on each new run of the container, or "For this Workspace" to do so automatically your current workspace. Note that you will still have to select your desired CMake Kit on each startup.

!["Always Configure" dialog](images/GettingStarted/always-configure.png)

If you did not open Visual Studio Code with the "folder" URL parameter, click File -> Open... to do so and choose `/SourceCache/HelloMinimal-CMake`. By default, `/SourceCache` will be opened, but this will not necessarily set up a working CMake project in a subdirectory. Hit "Enter".

!["Open" dialog](images/GettingStarted/open.png)
!["Open" dialog 2](images/GettingStarted/open2.png)

Once you do so, you should see `CMakeLists.txt`, `hello.swift`, `hikit.swift`, and, if you chose "For this Workspace", a `.vscode` directory.

![File listing](images/GettingStarted/files.png)

At the bottom of the screen, your toolbar will have CMake information. Ensure that the "Linux x86_64" kit is selected, and click the "Build:" button (in the future, if you want to rebuild only specific CMake targets, you can click "\[all\]" and select them specifically).

![CMake toolbar](images/GettingStarted/toolbar.png)

Your program is now compiled; now let's test it out. Open a shell with "Ctrl-`" (Ctrl-Backtick), and run it with:

```Shell
$ /BinaryCache/HelloMinimal-CMake/Debug/hello
```

![Hello World program](images/GettingStarted/hello-world.png)

Congratulations! You've built and run your first Swift program with swift-build-configuration!

### Windows
See documentation [here](docs/Windows.md)

## Status

**Windows Toolchains**

| Provider | Build | Status |
| - | :-: | - |
| Facebook | **x64 (VS2017)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/x64%20Toolchain%20(Facebook%20-%20VS2017)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=5&branchName=master) |
| Microsoft | **x64 (VS2017)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/x64%20Toolchain%20(VS2017)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=1&branchName=master) |
| Microsoft | **x64 (VS2019)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/x64%20Toolchain%20(VS2019)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=7&branchName=master) |
| Microsoft | **ARM64 (VS2019)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/ARM64%20Toolchain%20(VS2019)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=8&branchName=master) |

**Linux Toolchains**

| Provider | Build | Status |
| - | :-: | - |
| FlowKey | **x64 (Ubuntu 18.04)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/x64%20toolchain%20(FlowKey%20-%20Ubuntu%2018.04)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=14&branchName=master) |

**macOS Toolchains**

| Provider | Build | Status |
| - | :-: | - |
| Microsoft | **x64 (mojave)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/x64%20toolchain%20(macOS%2010.14)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=15&branchName=master) |

**SDKs**

| Build | Status |
| :-: | - |
| **Windows SDK (ARM/ARM64/X64/X86)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Windows%20SDK%20(VS2017)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=2&branchName=master) |
| **Android SDK (ARM/ARM64/X64/X86)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/android%20SDK%20(VS2019)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=4&branchName=master) |
| **Linux SDK (X64)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Linux%20SDK%20(flowkey%20-%20Ubuntu%2018.04)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=13&branchName=master) |

**Developer Tools**

| Build | Status |
| :-: | - |
| **Linux (llbuild, tools-support-core) (X64)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Linux%20Developer%20Tools?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=19&branchName=master) |

**Dependencies**

| Build | Status |
| :-: | - |
| **ICU** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/ICU?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=9&branchName=master) |
| **XML2** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/XML2?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=10&branchName=master) |
| **CURL** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/CURL?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=11&branchName=master) |
| **SQLite3** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/SQLite?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=12&branchName=master) |
| **ZLIB** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/zlib?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=16&branchName=master) |

**MSIs**

| Build | Status |
| :-: | - |
| **Windows x64 (VS2017) Toolchain** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Windows%20x64%20Toolchain%20(VS2017)%20MSI?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=21&branchName=master) |
| **Windows x64 (VS2019) Toolchain** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/x64%20Toolchain%20(VS2019)%20MSI?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=22&branchName=master) |

**deb Packages**

| Build | Status |
| :-: | - |
| **Linux x64 (Ubuntu 18.04) Toolchain** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Linux%20(Ubuntu%2018.04)%20x64%20Toolchain%20(DEB)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=23&branchName=master) |
| **Linux Swift SDK (Ubuntu 18.04)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Linux%20Swift%20SDK%20(DEB)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=24&branchName=master) |
| **Android Swift SDK (Ubuntu 18.04)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Android%20(AArch64)%20SDK%20(DEB)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=26&branchName=master) |
| **Windows Swift SDK (Ubuntu 18.04)** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Windows%20Swift%20SDK%20(DEB)?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=27&branchName=master) |

**docker images**

| Build | Status |
| :-: | - |
| **Ubuntu 18.04 VSCode** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Ubuntu%2018.04%20Image?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=25&branchName=master) |
