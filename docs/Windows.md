### Getting Started (Windows)

#### The Windows SDK and the Native Tools Command Prompt

You will need an installation of the Windows SDK to develop with the Swift Toolchain described here. An easy way to get the Windows SDK is to install Visual Studio, Visual Studio 2017 or later is needed. The following instructions suppose that you have Visual Studio 2019 installed. (Replace `2019` by `2017` in the instructions if you use Visual Studio 2017.) The installation of Visual Studio will also make the `x64 Native Tools Command Prompt ...` available, it should be accessible from the `Visual Studio ...` folder in the Start menu.

Most of the following commands are to be executed from within this Native Tools Command Prompt. Be sure to always start the `x64` version of the Native Tools Command Prompt.

#### Files for the Windows SDK

You will need to copy a few files into the Windows SDK to make it usable for Swift development. (This is a one-time install, you do not need to update those files when you install newer versions of the Swift Toolchain.) As you might need administrator rights to copy files into the Visual Studio installation directory, for the following four commands (and for those commands only) open the Native Tools Command Prompt with administrator rights. Otherwise, you might get a "Permission denied" error for some of those commands. Be sure that all commands have been successfully executed before continuing.

To open the Native Tools Command Prompt with administrator rights, navigate to the according entry in the start menu, right-click on that entry and choose "Open location" in the context menu. Then right-click the according file (that is actually a link) and choose "Run as administrator".

Then execute the following four commands from within the Native Tools Command Prompt:

```cmd
curl -L "https://raw.githubusercontent.com/apple/swift/main/stdlib/public/Platform/ucrt.modulemap" -o "%UniversalCRTSdkDir%\Include\%UCRTVersion%\ucrt\module.modulemap"
curl -L "https://raw.githubusercontent.com/apple/swift/main/stdlib/public/Platform/visualc.modulemap" -o "%VCToolsInstallDir%\include\module.modulemap"
curl -L "https://raw.githubusercontent.com/apple/swift/main/stdlib/public/Platform/visualc.apinotes" -o "%VCToolsInstallDir%\include\visualc.apinotes"
curl -L "https://raw.githubusercontent.com/apple/swift/main/stdlib/public/Platform/winsdk.modulemap" -o "%UniversalCRTSdkDir%\Include\%UCRTVersion%\um\module.modulemap"
```

Close this instance of the Native Tools Command Prompt after those commands have been successfully executed.

#### Swift Toolchain & Platform SDK concepts

The installation instructions that follow will result in a directory tree that has a well thought-out structure. To understand this directory structure better you may consult [the details document](details.md).

#### Downloading the nightlies

1. Go to [https://compnerd.visualstudio.com/swift-build](https://compnerd.visualstudio.com/swift-build).
2. Choose `Pipelines` > `Pipelines` from the left of the dashboard.
3. Use the filter symbol to search for "VS2019".
4. Click on the appropriate pipeline (e.g. `VS2019`).
5. The list of the runs will be displayed, scroll down until you see the first successful build (with a green OK symbol) and click on it.
6. Click the link under "Artifacts:".
7. Download windows-toolchain-amd64.msi, windows-sdk.msi, and windows-runtime-amd64.msi by clicking on the appropriate down-arrows on the right. Be sure to really download these files from the same build (i.e. do not switch the build for the next download, and be careful when updating). These files will be downloaded as zip files. Unless they are not automatically unzipped during the download process, unzip them to obtain \*.msi files in the extracted directories.

#### Installing the nightlies

These \*.msi files install the files to `C:\Library`. The complete Library directory can later be copied to a different location to be used there (but you have to change the PATH environment variable then).

To install the Swift Toolchain and Swift Windows SDK, run the installers windows-toolchain-amd64.msi and windows-sdk.msi. To install the Swift Runtime, run the installer windows-runtime-amd64.msi.

The installation of the Swift Toolchain adds the following value to the system PATH environment variable:

`\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain\usr\bin`

The installation of the Swift Runtime adds the following value to the system PATH environment variable:

`\Library\Swift\Current\bin`

#### Further requirements: CMake

On Windows, the most convenient setup for building Swift projects currently involves the use of CMake. This requires CMake 3.15+ for Swift support. CMake 3.16+ is recommended. You can download CMake from [https://cmake.org](https://cmake.org/).

#### Further requirements: ICU

You will need the ICU libraries from [ICU - International Components for Unicode](http://site.icu-project.org/). The nightlies are built against ICU 64.2 from the ICU project. You can download the binaries for that via [http://download.icu-project.org/files/icu4c/64.2/icu4c-64_2-Win64-MSVC2017.zip](http://download.icu-project.org/files/icu4c/64.2/icu4c-64_2-Win64-MSVC2017.zip). In these instructions we assume you rename the extracted ICU folder `icu4c-64_2-Win64-MSVC2017` to `icu-64.2` and move it to `C:\Library` and that you rename `bin64` to `bin`. The path to that `bin` should be added to the PATH environment variable.

#### Building Swift code

You should use a CMake project to build a Swift program. As an example CMake project use the "HelloWorld-CMake" example from [https://github.com/compnerd/swift-cmake-demo](https://github.com/compnerd/swift-cmake-demo) and use the following commands from within the project directory to build the project for Windows:

```cmd
SET INSTALLATION_DIR=C:
SET SDK=%INSTALLATION_DIR%\Library\Developer\Platforms\Windows.platform\Developer\SDKs\Windows.sdk
SET OS=windows
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=YES -D CMAKE_Swift_FLAGS="-sdk %SDK% -I %SDK%/usr/lib/swift -L %SDK%/usr/lib/swift/%OS%"
cd build
ninja
ninja test
```

Here, the variables INSTALLATION_DIR, SDK, and OS are just added for clarity of the subsequent command (they should not contain spaces). Execute these commands from the Native Tools Command Prompt (or set needed paths before executing). Note that the cmake executable to be used is the one mentioned above. (Try `cmake -version` to see which CMake version is actually being called.)

#### Running the Swift program on the development machine

There is no need to call the compiled program from the Native Tools Command Prompt.

The addition of `C:\Library\Swift\Current\bin` to the PATH environment variable by the Swift Runtime installer ensures that the program can be run on the development machine. `C:\Library\Swift\Current\bin` contains the DLL files needed to run a Swift program (besides the fact that the DLL files from the ICU project icudt\*.dll, icuin\*.dll, icuio\*.dll, icutu\*.dll, and icuuc\*.dll have to be in your path).

Of course, if you place the according DLL files from those directories into the same directory beside your executable (just copy them, do not move them!), you do not need the according additions to the PATH environment variable.

Note that the files in `C:\Library\Swift\Current\bin` might be incomplete: depending on the use case, you might need some more files (see the error messages when trying to run the program). You should find missing files in

`C:\Library\Developer\Platforms\Windows.platform\Developer\SDKs\Windows.sdk\usr\bin`

Copy the missing files to `C:\Library\Swift\Current\bin` (again, be sure not to move them). (But note that a new installation of the Swift Runtime does not update those copied files, so before installing a new Swift Runtime, first uninstall the old Swift Runtime and then delete all files in `C:\Library\Swift\Current\bin`.)

_Tip:_ When calling your program from the command line, first execute the command `chcp 65001` to ensure that Unicode characters are printed correctly inside the Windows command shell.

#### Running the Swift program on any machine

To run the Swift program on another machine, in addition to the files mentioned in the last section, the files from the "Visual C++ Redistributable" in the according version have to be available on that machine (i.e. they have to be in your path). They can be made available by installing the according "Visual C++ Redistributable". As an alternative, according to [Distributable Code for Visual Studio 2019](https://docs.microsoft.com/en-us/visualstudio/releases/2019/redistribution) the files inside `[VisualStudioFolder]\VC\redist` are allowed to be part of your application (consider the files inside the subfolder `x64\*.CRT`). Please consult the Microsoft documentation to know which files you should bundle with your application.

#### Legal statement

You are responsible for any files that you distribute with your application. Read the license files for any files you want to distribute.
