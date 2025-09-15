# Building the toolchain on Windows

Visual Studio 2022 is required to build Swift on Windows; any edition is fine.
Visual Studio 2017 should be possible to use, though it may require some
additional work to repair the build.  Visual Studio 2019 can be used to build,
though some of the automation will need to be adjusted for paths.

## Preflight

> [!IMPORTANT]
> The following commands must be run in the Windows Command Prompt launched from
the start menu. They wil not work if run in Windows Powershell or if run in a
Windows Command Prompt launched from inside an existing installation of Visual
Studio.

### Visual Studio

Installing Visual Studio can be done manually or in an unattended manner.  The
following snippet installs the necessary components of Visual Studio 2022 in an
automated fashion.

```cmd
curl.exe -sOL https://aka.ms/vs/17/release/vs_community.exe
vs_community.exe ^
  --add Microsoft.NetCore.Component.SDK ^
  --add Microsoft.VisualStudio.Component.Git ^
  --add Microsoft.VisualStudio.Component.VC.CMake.Project ^
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
  --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 ^
  --add Microsoft.VisualStudio.Component.VC.ATL ^
  --add Microsoft.VisualStudio.Component.VC.ATL.ARM64 ^
  --add Microsoft.VisualStudio.Component.Windows10SDK ^
  --add Microsoft.VisualStudio.Component.Windows11SDK.22621
del /q vs_community.exe
```

### Install Python

The `repo` tool uses Python, and as such, we need a Python installation on the host. We recommend installing **Python 3.10.1** to ensure compatibility with the provided scripts and examples. Download and install Python 3.10.1 for your platform from [https://www.python.org/downloads/release/python-3101/](https://www.python.org/downloads/release/python-3101/).

### Enable Symbolic Links Support

> [!NOTE]
> This step only needs to be completed if your User is not an Administrator, as Adminstrators already have permission to create symbolic links.

Grant your user the `SeCreateSymbolicLinkPrivilege` rights.  This can be done by
applying a Group Policy Object to the system.  Run `gpedit.msc` and navigate to

~~~
Computer Configuration > Windows Settings > Security Settings > Local Policies > User Rights Assignment
~~~

In the `Create symbolic links` entry, add your user.  You will need to restart
your session for the permission to be applied globally.

See [Microsoft documentation](https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/create-symbolic-links)
for additional information about this and the implications of changing this
permission.

### Enable Symbolic Links, Line Ending Conversion in Git

Some of the repositories depend on symbolic links when checking out the sources.
Additionally, some of the test inputs are line-ending sensitive and will need to
be checked out with a specific line ending.  You can simply set the global
defaults to ensure that the features are configured properly for all
repositories.

```cmd
git config --global --add core.autocrlf false
git config --global --add core.symlinks true
```

### Environment Setup

The remainder of the instructions assume that everything is being performed in
the instruction standard location.  The sources are expected to reside on a
drive labelled `S`.  If your sources are on another drive letter, you can use
the `subst` command to create a temporary, session local, drive mapping.

```cmd
subst S: %UserProfile%\source
```

The development drive must be formatted with NTFS or ReFS to ensure that
symbolic link support is available.  ExFAT does not support this functionality,
and while portable, would not allow required functionality to build Swift.

### Cloning Repositories

The easiest way to clone the repositories is by using the
[repo tool](https://gerrit.googlesource.com/git-repo).  See the documentation
from repo to install repo.

```cmd
S:
md Applications
curl.exe -sLo S:\Applications\repo https://storage.googleapis.com/git-repo-downloads/repo
md SourceCache
cd SourceCache
set PYTHONUTF8=1
python S:\Applications\repo init -u https://github.com/compnerd/swift-build
python S:\Applications\repo sync -j 8
```

Subsequently, you can update all the repositories using `python S:\Applications\repo sync`.

If you wish to sync to a point that is known to build successfully, you can use the smart sync option:

```
python S:\Applications\repo sync -s
```

You may also sync to specific toolchain versions by providing `repo` with the corresponding manifest file. Download `swift-build/stable.xml` at some revision, then sync with
```
python S:\Applications\repo sync -m path\to\stable.xml
```

If you wish to build a specific release branch, you can specify the `-b` (branch) option to `repo` to checkout the branch:
```
python S:\Applications\repo init -b release/6.0
python S:\Applications\repo sync
```

You may also do this at the initial checkout time as:
```
python S:\Applications\repo init -u https://github.com/compnerd/swift-build -b release/6.0
```

## Building

The full toolchain can be built in an automated fashion.  The following script
will perform a build and package of the toolchain.

```
S:\SourceCache\swift\utils\build.cmd
```

### Building for local debugging and testing

Additional `-DebugInfo` build script flag is required to build to build the toolchain with
debug information. For example, the following script invocation
will build the toolchain with PDB debug information, and will also skip the
installer packaging, which is rarely needed for local development.

```
S:\SourceCache\swift\utils\build.cmd -DebugInfo -SkipPackaging
```

The `-Test` flag can be used to build the tests for a toolchain component. For instance,
the following script invocation will ensure that the test targets for all components
that support testing are built:

```
S:\SourceCache\swift\utils\build.cmd -DebugInfo -SkipPackaging -Test '*'
```

### Speeding up the build with sccache

The `-EnableCaching` flag can be used to speed up the build. The
requirement is that `sccache` is installed and available on the shell
path. Sccache is available from
[here](https://github.com/mozilla/sccache/releases). Note that it will
help speed up the build of the C/C++ code but not the Swift code as
`sccache` doesn't currently support Swift.

```
S:\SourceCache\swift\utils\build.cmd -EnableCaching
```

## Using the Toolchain

### Environment Setup

The Windows toolchain depends on some environment variables.  If you wish to use
the locally built toolchain without installing with the distribution packaging,
you will need to manually configure the enviornment everytime you wish to use
the toolchain.

> [!CAUTION]
> **DO NOT** add this to your environment by default.  The normal toolchain build will not function properly with the environment configuration.

```cmd
set SDKROOT=S:\Program Files\Swift\Platforms\Windows.platform\Developer\SDKs\Windows.sdk
path S:\b\Python%PROCESSOR_ARCHITECTURE%-3.10.1\tools;S:\Program Files\Swift\Runtimes\0.0.0\usr\bin;S:\Program Files\Swift\Toolchains\0.0.0+Asserts\usr\bin;%PATH%
```

### PowerShell Helper

The following content in your Powershell profile file (whose path is stored in the built-in `$Profile` variable) would help quickly switch a shell to the proper configuration for using the just built toolchain.

```pwsh
function Set-SwiftEnv {
  $SwiftRoot = "S:\Program Files\Swift"
  $env:SDKROOT = "${SwiftRoot}\Platforms\Windows.platform\Developer\SDKs\Windows.sdk"
  $env:Path = "S:\b\Python${env:PROCESSOR_ARCHITECTURE}-3.10.1\tools;${SwiftRoot}\Runtimes\0.0.0\usr\bin;${SwiftRoot}\Toolchains\0.0.0+Asserts\usr\bin;${env:Path}"
}
Set-Alias -Name SwiftEnv -Value Set-SwiftEnv
```

It can be used by sourcing the file and executing the function as follows:
```pwsh
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
. $Profile
Set-SwiftEnv
```

## Troubleshooting

If you run into build failures with the following errors:
```
clang: error: no such file or directory: '\INCREMENTAL:NO'
clang: error: no such file or directory: '\OPT:REF'
clang: error: no such file or directory: '\OPT:ICF'
```
the reason is that the CMake on your system is too _new_. The latest version of CMake you should use is [CMake 3.29.x](https://cmake.org/files/v3.29/). 
