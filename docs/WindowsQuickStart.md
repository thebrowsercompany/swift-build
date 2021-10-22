# Building the toolchain on Windows

---

Visual Studio 2022 is required to build Swift on Windows; any edition is fine.
Visual Studio 2017 should be possible to use, though it may require some
additional work to repair the build.  Visual Studio 2019 can be used to build,
though some of the automation will need to be adjusted for paths.

## Preflight

### Visual Studio

Installing Visual Studio can be done manually or in an unattended manner.  The
following snippet installs the necessary components of Visual Studio 2022 in an
automated fashion.

```cmd
curl.exe -sOL https://aka.ms/vs/17/release/vs_community.exe
vs_community ^
  --add Component.CPython3.x64 ^
  --add Microsoft.VisualStudio.Component.Git ^
  --add Microsoft.VisualStudio.Component.VC.ATL ^
  --add Microsoft.VisualStudio.Component.VC.CMake.Project ^
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
  --add Microsoft.VisualStudio.Component.Windows10SDK ^
  --add Microsoft.VisualStudio.Component.Windows10SDK.22000
del /q vs_community.exe
```

### Enable Symbolic Links Support

Grant your user the `SeCreateSymbolicLinkPrivilege` rights.  This can be done by
applying a Group Policy Object to the system.  Run `gpedit.msc` and navigate to

~~~
Computer Configuration\Windows Settings\Security Settings\Local Policies\User Rights Assignment
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

### Cloning Repositories

The easiest way to clone the repositories is by using the
[repo tool](https://gerrit.googlesource.com/git-repo).  See the documentation
from repo to install repo.

```cmd
S:
md SourceCache
cd SourceCache
repo init -u https://github.com/compnerd/swift-build
repo sync -j 8
```

Subsequently, you can update all the repositories using `repo sync`.

### Configure Support FIles

In order to import the MSVC and WinSDK headers as modules into Swift code, the
components must be modularized.  This is done by adding in module map files to
describe the modules.  The following setups symlinks to inject the module map
definitions into the SDK.

> **NOTE:** this step needs to be re-run after every VS update.

```cmd
del /Q "%UniversalCRTSdkDir%\Include\%UCRTVersion%\ucrt\module.modulemap"
del /Q "%UniversalCRTSdkDir%\Include\%UCRTVersion%\um\module.modulemap"
del /Q "%VCToolsInstallDir%\include\module.modulemap"
del /Q "%VCToolsInstallDir%\include\visualc.apinotes"
mklink "%UniversalCRTSdkDir%\Include\%UCRTVersion%\ucrt\module.modulemap" S:\SourceCache\swift\stdlib\public\Platform\ucrt.modulemap
mklink "%UniversalCRTSdkDir%\Include\%UCRTVersion%\um\module.modulemap" S:\SourceCache\swift\stdlib\public\Platform\winsdk.modulemap
mklink "%VCToolsInstallDir%\include\module.modulemap" S:\SourceCache\swift\stdlib\public\Platform\visualc.modulemap
mklink "%VCToolsInstallDir%\include\visualc.apinotes" S:\SourceCache\swift\stdlib\public\Platform\visualc.apinotes
```

## Building

### Entering the Correct Environment

Visual Studio provides a custom shell for development which is required for
building.  It setups the environment appropriately for building and the build
system relies on that.  We assume that any shell snippets are being executed
within the "`x64 Native Tools Command Prompt for Visual Studio ____`".

### Building

The full toolchain can be built in an automated fashion.  The following script
will run a complete build of the toolchain, but will not package the toolchain.

```
S:\SourceCache\swift-build\build.cmd
```

## Using the Toolchaain

### Environment Setup

The Windows toolchain depends on some environment variables.  If you wish to use
the locally built toolchain without installing with the distribution packaging,
you will need to manually configure the enviornment everytime you wish to use
the toolchain.

> **NOTE:** DO NOT add this to your environment by default.  The normal
> toolchain build will not function properly with the environment configuration.

```cmd
set DEVELOPER_DIR=S:\Library\Developer
set SDKROOT=S:\Library\Developer\Platforms\Windows.platform\Developer\SDKs\Windows.sdk
path S:\Library\icu-69.1\usr\bin;S:\Library\Developer\Platforms\Windows.platform\Developer\SDKs\Windows.sdk\usr\bin;S:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain\usr\bin;%PATH%
```
