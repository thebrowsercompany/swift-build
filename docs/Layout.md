Windows Toolchain Layout
========================

The Windows toolchain layout is a layout which is derived from a combination of learnings from Windows, Linux, and macOS file system patterns. Although the layout is not particularly traditional to Windows, it allows for a flexible approach to composing the toolchain by enabling multiple individual MSIs to compose a whole. Optional features can easily be removed and things can be found relative to the root of the installation.

Legacy Issues
-------------

1. The toolchain is currently installed into `%SystemDrive%\Library\Developer`.  This path is a legacy layout and ideally the default installation path would be `%SystemDrive%\Developer`.  The `Developer` directory is intended to home all the developer products required for building software.

2. The toolchain is currently always labelled as `unknown-Asserts-development.xctoolchain`.  The toolchain should be renamed to a `.toolchain` to reflect that it is a toolchain bundle.  There is no reason for the suffix to be `.xctoolchain`.

3. The toolchain is currently unversioned, always stating to be the "development" release.  This is not entirely accurate, as there are versioned releases.  These toolchains should be updated to explicitly state their version.  This allows the parallel installation of multiple release toolchains and the current development toolchain.

4. The SDKs are named *`Identifier`*`.sdk` rather than being versioned.  The SDKs are meant to be versioned with the unversioned name being a symbolic link to the newest SDK.

Layout Components
-----------------

- `/Developer`

Homes the entirety of the developer content.  This includes the toolchain, the platform specific content, and the platform SDKs.

- `/Developer/Toolchains`

This create a substructure for multiple parallel toolchain installations.  The toolchains are identified by their name in this subdirectory.  The toolchains are recommended to be named as:

*`VENDOR`*-*`VARIANT`*-*`VERSION`*

The vendor is the vendor identifier string, e.g. Apple, Microsoft, etc.  In the case that there is no vendor associated with the toolchain, the traditional placeholder `unknown` may be used.  This label is the same label associated with the target triple for an unknown vendor.

The variant allows for multiple variants of the toolchain in Pascal case.  Currently, this project generates a toolchain which has assertions enabled.  Although this comes at a slight cost when using the toolchain, it ensures that any assumptions that the toolchain makes holds and that code is not silently miscompiled.  As an example, if the toolchain was built with assertions, it would be possible to use `NoAsserts` in the variant, enabling parallel installation of an assertions enabled and disabled toolchain.

The final component of the toolchain identifier is the version.  If the toolchain is a development snapshot, the version can be replaced with the phrase `development` to indicate that this is a development snapshot of the toolchain.  This enables the installation of multiple released versions of the toolchain and a development toolchain snapshot.

- `/Developer/Toolchains/`*`Identifier`*`.toolchain`

This location homes the entire toolchain.  The toolchain bundle has the "modern" traditional Unix layout of a `/usr` root.  This is merely for convenience and does not serve any purpose.

The toolchain binaries (tools) reside in `/usr/bin`.  This includes complete tools like the C/C++/Swift drivers, the linker, and binary tools, as well as symbolic links for alternate behaviour of the tools (e.g. the librarian and archiver are a single tool with the name of the binary indicating the behaviour).  This is in the Unix spirit of multicall binaries.

The toolchain also provides some headers which reside in `/usr/include`.  These headers are meant for building tooling through things such as `SourceKit` or the LLVM C interfaces.   It also may home headers for other support libraries meant for development (e.g. `SwiftDemangle` provides an API to undecorate Swift symbols).

The compiler requires certain other dependencies at runtime.  These dependencies reside in `/usr/lib`.  This includes items such as the compiler resource directory (headers and libraries consumed by the compiler while building applications, usually emitted _into_ the application, e.g. `compiler-rt`).  It also homes the support libraries for the toolchain such as the LTO plugin for the linker.

Platform agnostic support data is placed in `/usr/share`.  This includes things like vim syntax highlighting rules, emacs mode files, and supporting scripts for things like `clang-format`.

- `/Developer/Platforms`

This directory homes the platform specific content.  Each platform is given a subdirectory allowing parallel installation of multiple platform specific content.  This is meant to enable cross-compilation and development of cross-platform applications.  It is recommended the platform directory be named as a platform bundle identified by the platform name.

Examples of platform content currently packaged by this project include `Windows.platform` and `Android.platform`.

- `/Developer/Platforms/`*`Identifier`*`.platform/Developer`

The platform specific developer content is found in this directory.  This is similar to the top-level `/Developer` directory in the sense that this homes content for development on the platform identified by *Identifier*.

- `/Developer/Platforms/`*`Identifier`*`.platform/Developer/Library`

When developing software, often times auxiliary libraries are needed for performing the development tasks.  This directory homes the shared libraries and associated files required for those tasks.  These libraries are not meant for redistribution but rather for use during the development cycle.  Note that they may not be executable on the platform where you are developing.

As an example, [XCTest](https://github.com/apple/swift-corelibs-xctest) binaries are provided in this directory.  If the platform being targeted is not the build platform, these binaries will not execute on the build host.  For example, If you are targeting the Android platform from Windows, the libraries here must be copied to the target platform (Android) environment before they can be executed.

- `/Developer/Platforms/`*`Identifier`*`.platform/Developer/SDKs`

This directory provies the SDK content for the platform.  The SDKs are recommended to be named as:

*`Identifier`*-*`Version`*`.sdk`

For example, if the SDK is for Windows 10.0.17763.0, the SDK should be named `Windows-10.0.17763.0.sdk`.  This allows for multiple parallel installation of SDKs allowing development against older and newer SDKs without worry.

The directory should include a symbolic link of the name *`Identifier`*`.sdk` which points to the most recent SDK.  It is expected the SDKs are backwards compatible (as on Windows) so that using a newer SDK would still enable development for an older platform.

This SDK is laid out similar to the "old" Linux layout with the structure being prefixed with the `/usr` root.

Headers for the system components are provided in `/usr/include`.

For platforms with linker interfaces (e.g. Windows) the `/usr/lib` directory should contain the import library or the linker interface file.  If the platform does not support that mechanism, it is required to provide the runtime components here (at the cost of a larger SDK and slower tooling).

Swift content is provided in the `/usr/lib` directory as is expected by the Swift tooling.

Environment Variables
---------------------

- `DEVELOPER_DIR` (`%SystemDrive%\Developer`)

This is the developer directory which is the root of the installation of all the developer content.

- `PLATFORM_NAME`

This is the platform being targeted (e.g. `Windows` or `Android`)

- `SDKROOT` (`%SystemDrive%\Developer\Platforms\%PLATFORM_NAME%.platform\Developer\SDKs\%PLATFORM_NAME%.sdk`)

This is the root of the SDK for the platform being targeted.
