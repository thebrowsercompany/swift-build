# Copyright 2020 Saleem Abdulrasool <compnerd@compnerd.org>
# Copyright 2023 Tristan Labelle <tristan@thebrowser.company>
# Copyright 2025 Fabrice de Gans <fabrice@thebrowser.company>

<#
.SYNOPSIS
Configures a CMake project for the Swift toolchain.

.DESCRIPTION
This script is used to configure a CMake project for building the Swift toolchain, it is meant to be
a rough equivalent of the `Build-CMakeProject()` function in `build.ps1` in the Swift repository.
This script and the equivalent function in `build.ps1` should be kept in sync as much as possible.

.PARAMETER ProjectName
The name of the project to build.

.PARAMETER SwiftVersion
The Swift compiler version being built.

.PARAMETER EnableCaching
Whether to enable the build cache, using `sccache`.

.PARAMETER DebugInfo
Whether to enable debug information generation for the build. Unlike the upstream `build.ps1`, this
is not configurable and always builds debug information in CodeView (PDB) format.

.PARAMETER BuildOS
The operating system where the build is being performed.

.PARAMETER BuildArch
The architecture of the system where the build is being performed.

.PARAMETER OS
The target operating system for this build.

.PARAMETER Arch
The target architecture for this build.

.PARAMETER SrcDir
The source directory for this project.

.PARAMETER BinDir
The binary output directory for this project.

.PARAMETER InstallDir
The directory where this project should be installed.

.PARAMETER PinnedSHA256
The SHA256 for the pinned toolchain.

.PARAMETER AndroidAPILevel
The version number of the Android API level to be used.

.PARAMETER AndroidClangVersion
The version number of the Android Clang toolchain to be used.

.PARAMETER NDKPath
The path to the Android NDK installation.

.PARAMETER SwiftSDKPath
The path to the Swift SDK to be used for building this project.

.PARAMETER UseMSVCCompilers
The set of languages to build with the MSVC compilers when building the project. Note that for
Android, this will be referring to the Clang toolchain provided by the NDK, not the MSVC toolchain.

.PARAMETER UseBuiltCompilers
The set of languages to build with the built compilers when building the project.

.PARAMETER UseBootstrapCompilers
The set of languages to build with the bootstrap Swift compilers when building the project.

.PARAMETER UseGNUDriver
Whether to use the GNU driver for building this project.

.PARAMETER CMakeDefines
A hashtable of CMake defines to be passed to the project. The keys are the CMake variable names
and the values are the values to be set. The values can be single tokens or arrays of tokens.

.PARAMETER CacheScript
The path to an optional CMake cache script to be used for this project.

#>

[CmdletBinding(PositionalBinding = $false)]
param
(
  [Parameter(Mandatory = $true)]
  [string] $ProjectName,

  [Parameter(Mandatory = $true)]
  [string] $SwiftVersion,

  [Parameter(Mandatory = $false)]
  [switch] $EnableCaching = $false,

  [Parameter(Mandatory = $false)]
  [switch] $DebugInfo = $false,

  [Parameter(Mandatory = $true)]
  [string] $BuildOS,

  [Parameter(Mandatory = $true)]
  [string] $BuildArch,

  [Parameter(Mandatory = $true)]
  [string] $OS,

  [Parameter(Mandatory = $true)]
  [string] $Arch,

  [Parameter(Mandatory = $true)]
  [string] $SrcDir,

  [Parameter(Mandatory = $true)]
  [string] $BinDir,

  [Parameter(Mandatory = $false)]
  [string] $InstallDir = "",

  [Parameter(Mandatory = $false)]
  [string] $AndroidAPILevel,

  [Parameter(Mandatory = $false)]
  [string] $AndroidClangVersion = "",

  [Parameter(Mandatory = $false)]
  [string] $NDKPath = "",

  [Parameter(Mandatory = $false)]
  [string] $SwiftSDKPath = "",

  [Parameter(Mandatory = $false)]
  [ValidateSet("ASM_MASM", "C", "CXX")]
  [string[]] $UseMSVCCompilers = @(),

  [ValidateSet("ASM", "C", "CXX", "Swift")]
  [string[]] $UseBuiltCompilers = @(),

  [ValidateSet("ASM", "C", "CXX", "Swift")]
  [string[]] $UseBootstrapCompilers = @(),

  [Parameter(Mandatory = $false)]
  [switch] $UseGNUDriver = $false,

  [Parameter(Mandatory = $false)]
  [hashtable] $CMakeDefines = @{},

  [Parameter(Mandatory = $false)]
  [string] $CacheScript = ""

)

function Add-KeyValueIfNew([hashtable]$Hashtable, [string]$Key, [string]$Value) {
  if (-not $Hashtable.Contains($Key)) {
    $Hashtable.Add($Key, $Value)
  }
}

function Add-FlagsDefine([hashtable]$Defines, [string]$Name, [string[]]$Value) {
  if ($Defines.Contains($Name)) {
    $Defines[$name] = @($Defines[$name]) + $Value
  } else {
    $Defines.Add($Name, $Value)
  }
}

$CMakeArch = switch ($OS) {
  'Windows' { $Arch.ToUpperInvariant() }
  'Android' {
    switch ($Arch) {
      'arm64' { 'aarch64' }
      'x86_64' { 'x86_64' }
      'i686' { 'i686' }
      'armv7' { 'armv7-a' }
      default { throw "Unsupported Android architecture: $Arch" }
    } 
  }
  "Darwin" { $Arch }
  default { throw "Unsupported OS: $OS" }
}

$Triple = switch ($OS) {
  'Windows' {
    switch ($Arch) {
      'x86' { "i686-unknown-pc-windows-msvc" }
      'amd64' { "x86_64-unknown-pc-windows-msvc" }
      'arm64' { "aarch64-unknown-pc-windows-msvc" }
      default { throw "Unsupported Windows architecture: $Arch" }
    }
  }
  'Android' {
    switch ($Arch) {
      'i686' { "i686-unknown-linux-android${AndroidAPILevel}" }
      'x86_64' { "x86_64-unknown-linux-android${AndroidAPILevel}" }
      'armv7' { "armv7-unknown-linux-androideabi${AndroidAPILevel}" }
      'arm64' { "aarch64-unknown-linux-android${AndroidAPILevel}" }
      default { throw "Unsupported Android architecture: $Arch" }
    }
  }
  'Darwin' { "${Arch}-apple-macosx15.0" }
  default { throw "Unsupported OS: $OS" }
}

$UseASM = $UseBuiltCompilers.Contains("ASM") -or $UseBootstrapCompilers.Contains("ASM")
$UseASM_MASM = $UseMSVCCompilers.Contains("ASM_MASM")
$UseC = $UseBuiltCompilers.Contains("C") -or $UseMSVCCompilers.Contains("C") -or $UseBootstrapCompilers.Contains("C")
$UseCXX = $UseBuiltCompilers.Contains("CXX") -or $UseMSVCCompilers.Contains("CXX") -or $UseBootstrapCompilers.Contains("CXX")
$UseSwift = $UseBuiltCompilers.Contains("Swift") -or $UseBootstrapCompilers.Contains("Swift")

# Add additional defines (unless already present)
$Defines = $CMakeDefines.Clone()

Add-KeyValueIfNew $Defines CMAKE_BUILD_TYPE Release

# Avoid specifying `CMAKE_SYSTEM_NAME` and `CMAKE_SYSTEM_PROCESSOR` on
# Windows and in the case that we are not cross-compiling.
if ($OS -ne $BuildOS -or $Arch -ne $BuildArch) {
  Add-KeyValueIfNew $Defines CMAKE_SYSTEM_NAME $OS
  Add-KeyValueIfNew $Defines CMAKE_SYSTEM_PROCESSOR $CMakeArch
}

# Always prefer the CONFIG format for the packages so that we can build
# against the build tree.
Add-KeyValueIfNew $Defines CMAKE_FIND_PACKAGE_PREFER_CONFIG YES

switch ($OS) {
  'Windows' {
    if ($UseASM) {
      $Driver = $(if ($UseGNUDriver) { "clang.exe" } else { "clang-cl.exe" })
      $ASM = if ($UseBuiltCompilers.Contains("ASM")) {
        "${env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/${Driver}"
      } elseif ($UseBootstrapCompilers.Contains("ASM")) {
        # The pinned toolchain is already in the path.
        $Driver
      }

      Add-KeyValueIfNew $Defines CMAKE_ASM_COMPILER $ASM
      Add-KeyValueIfNew $Defines CMAKE_ASM_FLAGS @("--target=$Triple")
      Add-KeyValueIfNew $Defines CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreadedDLL "/MD"

      if ($DebugInfo) {
        $ASMDebugFlags = if ($CDebugFormat -eq "dwarf") {
          if ($UseGNUDriver) {
            @("-gcodeview")
          } else {
            @("-clang:-gcodeview")
          }

          # CMake does not set a default value for the ASM compiler debug
          # information format flags with non-MSVC compilers, so we explicitly
          # set a default here.
          Add-FlagsDefine $Defines CMAKE_ASM_COMPILE_OPTIONS_MSVC_DEBUG_INFORMATION_FORMAT_Embedded $ASMDebugFlags
        }
      }
    }

    if ($UseASM_MASM) {
      $ASM_MASM = if (${Arch} -eq "x86") {
        "ml.exe"
      } else {
        "ml64.exe"
      }

      Add-KeyValueIfNew $Defines CMAKE_ASM_MASM_COMPILER $ASM_MASM
      Add-KeyValueIfNew $Defines CMAKE_ASM_MASM_FLAGS @("/nologo" , "/quiet")
    }

    if ($UseC) {
      $CC = if ($UseMSVCCompilers.Contains("C")) {
        "cl.exe"
      } else {
        $Driver = $(if ($UseGNUDriver) { "clang.exe" } else { "clang-cl.exe" })
        if ($UseBuiltCompilers.Contains("C")) {
          "${env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/${Driver}"
        } elseif ($UseBootstrapCompilers.Contains("C")) {
          # The pinned toolchain is already in the path.
          $Driver
        }
      }

      Add-KeyValueIfNew $Defines CMAKE_C_COMPILER $CC
      Add-KeyValueIfNew $Defines CMAKE_C_COMPILER_TARGET $Triple

      $CFLAGS = if ($UseGNUDriver) {
        # TODO(compnerd) we should consider enabling stack protector usage for standard libraries.
        @("-fno-stack-protector", "-ffunction-sections", "-fdata-sections", "-fomit-frame-pointer")
      } elseif ($UseMSVCCompilers.Contains("C")) {
        @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:preprocessor", "/Zc:inline")
      } else {
        # clang-cl does not support the /Zc:preprocessor flag.
        @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline")
      }

      Add-FlagsDefine $Defines CMAKE_C_FLAGS $CFLAGS
    }

    if ($UseCXX) {
      $CXX = if ($UseMSVCCompilers.Contains("CXX")) {
        "cl.exe"
      } else {
        $Driver = $(if ($UseGNUDriver) { "clang++.exe" } else { "clang-cl.exe" })
        if ($UseBuiltCompilers.Contains("CXX")) {
          "${env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/${Driver}"
        } elseif ($UseBootstrapCompilers.Contains("CXX")) {
          # The pinned toolchain is already in the path.
          $Driver
        }
      }

      Add-KeyValueIfNew $Defines CMAKE_CXX_COMPILER $CXX
      Add-KeyValueIfNew $Defines CMAKE_CXX_COMPILER_TARGET $Triple

      $CXXFLAGS = if ($UseGNUDriver) {
        # TODO(compnerd) we should consider enabling stack protector usage for standard libraries.
        @("-fno-stack-protector", "-ffunction-sections", "-fdata-sections", "-fomit-frame-pointer")
      } elseif ($UseMSVCCompilers.Contains("CXX")) {
        @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:preprocessor", "/Zc:inline", "/Zc:__cplusplus")
      } else {
        # clang-cl does not support the /Zc:preprocessor flag.
        @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline", "/Zc:__cplusplus")
      }

      Add-FlagsDefine $Defines CMAKE_CXX_FLAGS $CXXFLAGS
    }

    if ($UseSwift) {
      if ($UseBuiltCompilers.Contains("Swift")) {
        Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_WORKS "YES"
      }

      $SWIFTC = if ($UseBuiltCompilers.Contains("Swift")) {
        "${env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/swiftc.exe"
      } elseif ($UseBootstrapCompilers.Contains("Swift")) {
        "swiftc.exe"
      }

      Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER $SWIFTC

      $TargetInfo = & $SWIFTC -target $Triple -print-target-info
      $TargetInfo = $TargetInfo | ConvertFrom-Json
      $TargetInfo = $TargetInfo.target
      Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_TARGET $TargetInfo

      # TODO(compnerd): remove this once we have the early swift-driver
      Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_USE_OLD_DRIVER "YES"

      [string[]] $SwiftFlags = if ($SwiftSDK) {
        @("-sdk", $SwiftSDK)
      } else {
        @()
      }

      $SwiftFlags += if ($DebugInfo) {
        @("-g", "-debug-info-format=codeview", "-Xlinker", "/DEBUG")
      } else {
        @("-gnone")
      }

      # Disable EnC as that introduces padding in the conformance tables
      $SwiftFlags += @("-Xlinker", "/INCREMENTAL:NO")
      # Swift requires COMDAT folding and de-duplication
      $SwiftFlags += @("-Xlinker", "/OPT:REF", "-Xlinker", "/OPT:ICF")

      Add-FlagsDefine $Defines CMAKE_Swift_FLAGS $SwiftFlags
      # Workaround CMake 3.26+ enabling `-wmo` by default on release builds
      Add-FlagsDefine $Defines CMAKE_Swift_FLAGS_RELEASE "-O"
      Add-FlagsDefine $Defines CMAKE_Swift_FLAGS_RELWITHDEBINFO "-O"
    }

    $LinkerFlags = if ($UseGNUDriver) {
      @("-Xlinker", "/INCREMENTAL:NO", "-Xlinker", "/OPT:REF", "-Xlinker", "/OPT:ICF")
    } else {
      @("/INCREMENTAL:NO", "/OPT:REF", "/OPT:ICF")
    }

    if ($DebugInfo) {
      if ($UseASM -or $UseC -or $UseCXX) {
        # Prefer `/Z7` over `/ZI`
        # By setting the debug information format, the appropriate C/C++
        # flags will be set for codeview debug information format so there
        # is no need to set them explicitly above.
        Add-KeyValueIfNew $Defines CMAKE_MSVC_DEBUG_INFORMATION_FORMAT Embedded
        Add-KeyValueIfNew $Defines CMAKE_POLICY_DEFAULT_CMP0141 NEW

        $LinkerFlags += if ($UseGNUDriver) {
          @("-Xlinker", "/DEBUG")
        } else {
          @("/DEBUG")
        }

      }
    }

    Add-FlagsDefine $Defines CMAKE_EXE_LINKER_FLAGS $LinkerFlags
    Add-FlagsDefine $Defines CMAKE_SHARED_LINKER_FLAGS $LinkerFlags
  }

  'Android' {
    $AndroidArchAbi = switch ($Arch) {
      'i686' { "x86" }
      'x86_64' { "x86_64" }
      'armv7' { "armeabi-v7a" }
      'arm64' { "arm64-v8a" }
      default { throw "Unsupported architecture: $Arch" }
    }
    $AndroidArchLLVM = switch ($BuildArch) {
      'amd64' { "x86_64" }
      'arm64' { "aarch64" }
      default { throw "Unsupported architecture: $Arch" }
    }
    $AndroidNDKPath = $NDKPath
    $AndroidPrebuiltRoot = "$AndroidNDKPath\toolchains\llvm\prebuilt\$($BuildOS.ToLowerInvariant())-$($AndroidArchLLVM)"
    $AndroidSysroot = "$AndroidPrebuiltRoot\sysroot"

    Add-KeyValueIfNew $Defines CMAKE_ANDROID_API "$AndroidAPILevel"
    Add-KeyValueIfNew $Defines CMAKE_ANDROID_ARCH_ABI "$AndroidArchAbi"
    Add-KeyValueIfNew $Defines CMAKE_ANDROID_NDK "$AndroidNDKPath"

    if ($UseASM) {
    }

    if ($UseC) {
      Add-KeyValueIfNew $Defines CMAKE_C_COMPILER_TARGET $Triple

      $CFLAGS = @("--sysroot=${AndroidSysroot}", "-ffunction-sections", "-fdata-sections")
      if ($DebugInfo) {
        $CFLAGS += @("-g", "-gsplit-dwarf")
      }
      Add-FlagsDefine $Defines CMAKE_C_FLAGS $CFLAGS
    }

    if ($UseCXX) {
      Add-KeyValueIfNew $Defines CMAKE_CXX_COMPILER_TARGET $Triple

      $CXXFLAGS = @("--sysroot=${AndroidSysroot}", "-ffunction-sections", "-fdata-sections")
      if ($DebugInfo) {
        $CXXFLAGS += @("-g", "-gsplit-dwarf")
      }
      Add-FlagsDefine $Defines CMAKE_CXX_FLAGS $CXXFLAGS
    }

    if ($UseSwift) {
      if ($UseBuiltCompilers.Contains("Swift")) {
        Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_WORKS "YES"
      }

      # FIXME(compnerd) remove this once the old runtimes build path is removed.
      Add-KeyValueIfNew $Defines SWIFT_ANDROID_NDK_PATH "$AndroidNDKPath"

      $SWIFTC = if ($UseBuiltCompilers.Contains("Swift")) {
        $SWIFTC = "${Env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/swiftc.exe"
      } else {
        # The pinned toolchain is already in the path.
        "swiftc.exe"
      }
      Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER $SWIFTC

      $TargetInfo = & $SWIFTC -target $Triple -print-target-info
      $TargetInfo = $TargetInfo | ConvertFrom-Json
      $TargetInfo = $TargetInfo.target
      Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_TARGET $TargetInfo

      # TODO(compnerd) remove this once we have the early swift-driver
      Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_USE_OLD_DRIVER "YES"

      $SwiftFlags = if ($SwiftSDK) {
        @(
          "-sdk", $SwiftSDK,
          "-sysroot", $AndroidSysroot
        )
      } else {
        @()
      }

      $SwiftFlags += @(
        "-Xclang-linker", "-target", "-Xclang-linker", $Triple,
        "-Xclang-linker", "--sysroot", "-Xclang-linker", $AndroidSysroot,
        "-Xclang-linker", "-resource-dir", "-Xclang-linker", "${AndroidPrebuiltRoot}\lib\clang\${AndroidClangVersion}"
      )

      $SwiftFlags += if ($DebugInfo) { @("-g") } else { @("-gnone") }

      Add-FlagsDefine $Defines CMAKE_Swift_FLAGS $SwiftFlags
      # Workaround CMake 3.26+ enabling `-wmo` by default on release builds
      Add-FlagsDefine $Defines CMAKE_Swift_FLAGS_RELEASE "-O"
      Add-FlagsDefine $Defines CMAKE_Swift_FLAGS_RELWITHDEBINFO "-O"
    }

    $UseBuiltASMCompiler = $UseBuiltCompilers.Contains("ASM")
    $UseBuiltCCompiler = $UseBuiltCompilers.Contains("C")
    $UseBuiltCXXCompiler = $UseBuiltCompilers.Contains("CXX")

    if ($UseBuiltASMCompiler -or $UseBuiltCCompiler -or $UseBuiltCXXCompiler) {
      # Use a built lld linker as the Android's NDK linker might be too old
      # and not support all required relocations needed by the Swift
      # runtime.
      $ld = "${Env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/ld.lld"
      Add-FlagsDefine $Defines CMAKE_SHARED_LINKER_FLAGS "--ld-path=$ld"
      Add-FlagsDefine $Defines CMAKE_EXE_LINKER_FLAGS "--ld-path=$ld"
    }

    # TODO(compnerd) we should understand why CMake does not understand
    # that the object file format is ELF when targeting Android on Windows.
    # This indication allows it to understand that it can use `chrpath` to
    # change the RPATH on the dynamic libraries.
    Add-FlagsDefine $Defines CMAKE_EXECUTABLE_FORMAT "ELF"
  }
}

if ($EnableCaching) {
  if ($UseC) {
    Add-KeyValueIfNew $Defines CMAKE_C_COMPILER_LAUNCHER "sccache"
  }

  if ($UseCXX) {
    Add-KeyValueIfNew $Defines CMAKE_CXX_COMPILER_LAUNCHER "sccache"
  }
}

if ($InstallDir) {
  Add-KeyValueIfNew $Defines CMAKE_INSTALL_PREFIX $InstallDir
}

# Generate the project
$cmakeGenerateArgs = @("-B", $BinDir, "-S", $SrcDir, "-G", "Ninja")
if ($CacheScript) {
  $cmakeGenerateArgs += @("-C", $CacheScript)
}

foreach ($Define in ($Defines.GetEnumerator() | Sort-Object Name)) {
  # The quoting gets tricky to support defines containing compiler flags args,
  # some of which can contain spaces, for example `-D` `Flags=-flag "C:/Program Files"`
  # Avoid backslashes since they are going into CMakeCache.txt,
  # where they are interpreted as escapes.
  if ($Define.Value -is [string]) {
    # Single token value, no need to quote spaces, the splat operator does the right thing.
    $Value = $Define.Value.Replace("\", "/")
  } else {
    # Flags array, multiple tokens, quoting needed for tokens containing spaces
    $Value = ""
    foreach ($Arg in $Define.Value) {
      if ($Value.Length -gt 0) {
        $Value += " "
      }

      $ArgWithForwardSlashes = $Arg.Replace("\", "/")
      if ($ArgWithForwardSlashes.Contains(" ")) {
        # Quote and escape the quote so it makes it through
        $Value += "\""$ArgWithForwardSlashes\"""
      } else {
        $Value += $ArgWithForwardSlashes
      }
    }
  }

  $cmakeGenerateArgs += @("-D", "$($Define.Key)=$Value")
}

Write-Host "ℹ️ Configuring project ${ProjectName}:"
Write-Host 'cmake `'
for ($i = 0; $i -lt $cmakeGenerateArgs.Length; $i += 1) {
  $Arg = $cmakeGenerateArgs[$i]
  if ($Arg -match '\s') {
    Write-Host "  `"$Arg`"" -NoNewline
  } else {
    Write-Host "  $Arg" -NoNewline
  }

  if ((-not ($Arg -match '^-')) -and ($i -lt ($cmakeGenerateArgs.Length - 1))) {
    # Write a newline for non-option arguments.
    Write-Host " ``"
  }
}
Write-Host "`n"

& cmake @cmakeGenerateArgs
if ($LASTEXITCODE -ne 0) {
  throw "CMake generation failed for project ${ProjectName} with exit code $LASTEXITCODE."
}
