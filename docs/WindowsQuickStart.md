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
  --add Component.CPython39.x64 ^
  --add Microsoft.NetCore.Component.SDK ^
  --add Microsoft.VisualStudio.Component.Git ^
  --add Microsoft.VisualStudio.Component.VC.CMake.Project ^
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
  --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 ^
  --add Microsoft.VisualStudio.Component.VC.ATL ^
  --add Microsoft.VisualStudio.Component.VC.ATL.ARM64 ^
  --add Microsoft.VisualStudio.Component.Windows10SDK ^
  --add Microsoft.VisualStudio.Component.Windows11SDK.22000
del /q vs_community.exe
```

### Enable Symbolic Links Support

> [!INFO] This step only needs to be completed if your User is not an Administrator, as
> Adminstrators already have permission to create symbolic links.

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
"%ProgramFiles(x86)%\Microsoft Visual Studio\Shared\Python39_64\python.exe" S:\Applications\repo init -u https://github.com/compnerd/swift-build
"%ProgramFiles(x86)%\Microsoft Visual Studio\Shared\Python39_64\python.exe" S:\Applications\repo sync -j 8
```

Subsequently, you can update all the repositories using `"%ProgramFiles(x86)%\Microsoft Visual Studio\Shared\Python39_64\python.exe" S:\Applications\repo sync`.

If you wish to sync to a point that is known to build successfull, you can use the smart sync option:

```
"%ProgramFiles(x86)%\Microsoft Visual Studio\Shared\Python39_64\python.exe" S:\Applications\repo sync -s
```

> [!NOTE]
> The first clone will fail if you do not have git-lfs. The failure is due to the inability to checkout the ICU data which is stored using LFS, but is not fatal in practice.

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
path S:\Program Files\Swift\Runtimes\0.0.0\usr\bin;S:\Program Files\Swift\Toolchains\0.0.0+Asserts\usr\bin;%PATH%
```

### PowerShell Helper

The following content in your Powershell profile file (whose path is stored in the built-in `$Profile` variable) would help quickly switch a shell to the proper configuration for using the just built toolchain.

```pwsh
function Set-SwiftEnv {
  $SwiftRoot = "S:\Program Files\Swift"
  $env:SDKROOT = "${SwiftRoot}\Platforms\Windows.platform\Developer\SDKs\Windows.sdk"
  $env:Path = "${env:ProgramFiles}\Python39;${SwiftRoot}\Runtimes\0.0.0\usr\bin;${SwiftRoot}\Toolchains\0.0.0+Asserts\usr\bin;${env:Path}"
}
Set-Alias -Name SwiftEnv -Value Set-SwiftEnv
```

It can be used by sourcing the file and executing the function as follows:
```pwsh
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
. $Profile
Set-SwiftEnv
```
