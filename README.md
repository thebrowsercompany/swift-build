# **Swift on Windows**
Windows nightlies built on Azure

### Status

| Build | Status |
|:-:|-|
| **Toolchain** | **x64 VS2017** [![Build Status](https://compnerd.visualstudio.com/windows-swift/_apis/build/status/Windows%20Toolchain?branchName=master)](https://compnerd.visualstudio.com/windows-swift/_build/latest?definitionId=1&branchName=master)<br />**x64 VS2019** [![Build Status](https://compnerd.visualstudio.com/windows-swift/_apis/build/status/x64%20Toolchain%20(VS2019)?branchName=master)](https://compnerd.visualstudio.com/windows-swift/_build/latest?definitionId=7&branchName=master) |
| **Windows SDK** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/Windows%20SDK?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=2?branchName=master) |
| **Android SDK** | [![Build Status](https://dev.azure.com/compnerd/windows-swift/_apis/build/status/android%20SDK?branchName=master)](https://dev.azure.com/compnerd/windows-swift/_build/latest?definitionId=4?branchName=master) |

### Getting Started
#### Downloading the nightlies

1. We assume you are reading these instructions on the Azure DevOps page for windows-swift at <https://dev.azure.com/compnerd/windows-swift>.
2. Choose `Pipelines` > `builds` from the left of the dashboard.
3. Click the most recent successful build.
4. At the top right of this page to the right of where it says `All logs` there is a three dot button. Under this choose `Artifacts` > `toolchain` to download the nightly toolchain to your machine.

#### Installing the nightlies

1. Extract the toolchain artifact.  We assume that the toolchain will be installed to `C:\Library`.  Extracting it to that location should give you a hierarchy that looks like `C:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain\usr\bin\swiftc.exe`.
2. In order to develop with this toolchain, you will need an installation of the Windows SDK.  The easiest way to do this is to install Visual Studio.  Additionally, you will need to copy a few files into the SDK to make it usable from swift.
```cmd
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/ucrt.modulemap" -o "%UniversalCRTSdkDir%\Include\%UCRTVersion%\ucrt\module.modulemap"
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/visualc.modulemap" -o "%VCToolsInstallDir%\include\module.modulemap"
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/visualc.apinotes" -o "%VCToolsInstallDir%\include\visualc.apinotes"
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/winsdk.modulemap" -o "%UniversalCRTSdkDir%\Include\%UCRTVersion%\um\module.modulemap"
```
3. You will need to add the ICU libraries for the target.  The nightlies are built against ICU 64.2 from the ICU project.  You can download the binaries for that from http://download.icu-project.org/files/icu4c/64.2/icu4c-64_2-Win64-MSVC2017.zip.
In these instructions we assume you rename the extracted icu folder `icu4c-64_2-Win64-MSVC2017` to `icu-64.2` and move it to `C:\Library` and that you rename `bin64` to `bin`.

#### Building and running swift code

1. To have the required Visual Studio toolchain available ensure you use the `x64 Native Tools Command Prompt for VS 2017` that came with Visual Studio. Search inside the Visual Studio application folder to find it.
2. You need to add the folder containing `swiftc.exe` to the `PATH` environment variable to use the toolchain.
3. You also need to add the folder containing the icu dlls to the `PATH` environment variable. 

This can be achieved by entering the following into the command line.
```cmd
path %PATH%;C:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain\usr\bin
path %PATH%;C:\Library\icu-64.2\bin
```

Alternatively, to make these changes persistent go to the Windows environment variables edit dialog found in `System Properties` > `Advanced` > `Environment Variables` and edit the path variable to add the following two new items.

```cmd
C:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain\usr\bin
C:\Library\icu-64.2\bin
```

**Note:** After modifying the environment variables using this dialog, running applications must be restarted in order for changes to take effect.
