#header goes here.

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
  [string[]] $UsePinnedCompilers = @(),

  [Parameter(Mandatory = $false)]
  [switch] $UseGNUDriver = $false,

  [Parameter(Mandatory = $false)]
  [string[]] $BuildTargets = @("default"),

  [Parameter(Mandatory = $false)]
  [hashtable] $CMakeDefines = @{},

  [Parameter(Mandatory = $false)]
  [string] $CacheScript = ""

)

$UseASM = $UseBuiltCompilers.Contains("ASM") -or $UsePinnedCompilers.Contains("ASM")
$UseASM_MASM = $UseMSVCCompilers.Contains("ASM_MASM")
$UseC = $UseBuiltCompilers.Contains("C") -or $UseMSVCCompilers.Contains("C") -or $UsePinnedCompilers.Contains("C")
$UseCXX = $UseBuiltCompilers.Contains("CXX") -or $UseMSVCCompilers.Contains("CXX") -or $UsePinnedCompilers.Contains("CXX")
$UseSwift = $UseBuiltCompilers.Contains("Swift") -or $UsePinnedCompilers.Contains("Swift")

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

$CMakeDefines['CMAKE_BUILD_TYPE'] = 'Release'

# Avoid specifying `CMAKE_SYSTEM_NAME` and `CMAKE_SYSTEM_PROCESSOR` on
# Windows and in the case that we are not cross-compiling.
if ($OS -ne $BuildOS -or $Arch -ne $BuildArch) {
  $CMakeDefines['CMAKE_SYSTEM_NAME'] = $OS
  $CMakeDefines['CMAKE_SYSTEM_PROCESSOR'] = $CMakeArch
}

switch ($OS) {
  'Windows' {
    if ($UseASM) {
      $Driver = $(if ($UseGNUDriver) { "clang.exe" } else { "clang-cl.exe" })
      $ASM = if ($UseBuiltCompilers.Contains("ASM")) {
        "${env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/${Driver}"
      } elseif ($UsePinnedCompilers.Contains("ASM")) {
        # The pinned toolchain is already in the path.
        $Driver
      }

      $CMakeDefines['CMAKE_ASM_COMPILER'] = $ASM
      $CMakeDefines['CMAKE_ASM_FLAGS'] = @("--target=$Triple")
      $CMakeDefines['CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreadedDLL'] = "/MD"
    }

    if ($UseASM_MASM) {
      $ASM_MASM = if (${Arch} -eq "x86") {
        "ml.exe"
      } else {
        "ml64.exe"
      }

      $CMakeDefines['CMAKE_ASM_MASM_COMPILER'] = $ASM_MASM
      $CMakeDefines['CMAKE_ASM_MASM_FLAGS'] = @("/nologo" , "/quiet")
    }

    if ($UseC) {
      $CC = if ($UseMSVCCompilers.Contains("C")) {
        "cl.exe"
      } else {
        $Driver = $(if ($UseGNUDriver) { "clang.exe" } else { "clang-cl.exe" })
        if ($UseBuiltCompilers.Contains("C")) {
          "${env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/${Driver}"
        } elseif ($UsePinnedCompilers.Contains("C")) {
          # The pinned toolchain is already in the path.
          $Driver
        }
      }

      $CMakeDefines['CMAKE_C_COMPILER'] = $CC
      $CMakeDefines['CMAKE_C_COMPILER_TARGET'] = $Triple

      $CFLAGS = if ($UseGNUDriver) {
        # TODO(compnerd) we should consider enabling stack protector usage for standard libraries.
        @("-fno-stack-protector", "-ffunction-sections", "-fdata-sections", "-fomit-frame-pointer")
      } elseif ($UseMSVCCompilers.Contains("C")) {
        @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:preprocessor", "/Zc:inline")
      } else {
        # clang-cl does not support the /Zc:preprocessor flag.
        @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline")
      }

      if ($DebugInfo) {
        if ($UsePinnedCompilers.Contains("C") -or $UseBuiltCompilers.Contains("C")) {
          if ($CDebugFormat -eq "dwarf") {
            $CFLAGS += if ($UseGNUDriver) {
              @("-gdwarf")
            } else {
              @("-clang:-gdwarf")
            }
          }
        }
      }

      $CMakeDefines['CMAKE_C_FLAGS'] = $CFLAGS
    }

    if ($UseCXX) {
      $CXX = if ($UseMSVCCompilers.Contains("CXX")) {
        "cl.exe"
      } else {
        $Driver = $(if ($UseGNUDriver) { "clang++.exe" } else { "clang-cl.exe" })
        if ($UseBuiltCompilers.Contains("CXX")) {
          "${env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/${Driver}"
        } elseif ($UsePinnedCompilers.Contains("CXX")) {
          # The pinned toolchain is already in the path.
          $Driver
        }
      }

      $CMakeDefines['CMAKE_CXX_COMPILER'] = $CXX
      $CMakeDefines['CMAKE_CXX_COMPILER_TARGET'] = $Triple

      $CXXFLAGS = if ($UseGNUDriver) {
        # TODO(compnerd) we should consider enabling stack protector usage for standard libraries.
        @("-fno-stack-protector", "-ffunction-sections", "-fdata-sections", "-fomit-frame-pointer")
      } elseif ($UseMSVCCompilers.Contains("CXX")) {
        @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:preprocessor", "/Zc:inline", "/Zc:__cplusplus")
      } else {
        # clang-cl does not support the /Zc:preprocessor flag.
        @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline", "/Zc:__cplusplus")
      }

      if ($DebugInfo) {
        if ($UsePinnedCompilers.Contains("CXX") -or $UseBuiltCompilers.Contains("CXX")) {
          if ($CDebugFormat -eq "dwarf") {
            $CXXFLAGS += if ($UseGNUDriver) {
              @("-gdwarf")
            } else {
              @("-clang:-gdwarf")
            }
          }
        }
      }

      $CMakeDefines['CMAKE_CXX_FLAGS'] = $CXXFLAGS
    }

    if ($UseSwift) {
      if ($UseBuiltCompilers.Contains("Swift")) {
        $CMakeDefines['CMAKE_Swift_COMPILER_WORKS'] = "YES"
      }

      $SWIFTC = if ($UseBuiltCompilers.Contains("Swift")) {
        "${env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/swiftc.exe"
      } elseif ($UsePinnedCompilers.Contains("Swift")) {
        "swiftc.exe"
      }

      $CMakeDefines['CMAKE_Swift_COMPILER'] = $SWIFTC

      $TargetInfo = & $SWIFTC -target $Triple -print-target-info
      $TargetInfo = $TargetInfo | ConvertFrom-Json
      $TargetInfo = $TargetInfo.target
      $CMakeDefines['CMAKE_Swift_COMPILER_TARGET'] = $TargetInfo

      # TODO(compnerd): remove this once we have the early swift-driver
      $CMakeDefines['CMAKE_Swift_COMPILER_USE_OLD_DRIVER'] = "YES"

      [string[]] $SwiftFlags = if ($SwiftSDK) {
        @("-sdk", $SwiftSDK)
      } else {
        @()
      }

      $SwiftFlags += if ($DebugInfo) {
        if ($SwiftDebugFormat -eq "dwarf") {
          @("-g", "-debug-info-format=dwarf", "-use-ld=lld-link", "-Xlinker", "/DEBUG:DWARF")
        } else {
          @("-g", "-debug-info-format=codeview", "-Xlinker", "/DEBUG")
        }
      } else {
        @("-gnone")
      }

      # Disable EnC as that introduces padding in the conformance tables
      $SwiftFlags += @("-Xlinker", "/INCREMENTAL:NO")
      # Swift requires COMDAT folding and de-duplication
      $SwiftFlags += @("-Xlinker", "/OPT:REF", "-Xlinker", "/OPT:ICF")

      $CMakeDefines['CMAKE_Swift_FLAGS'] = $SwiftFlags
      # Workaround CMake 3.26+ enabling `-wmo` by default on release builds
      $CMakeDefines['CMAKE_Swift_FLAGS_RELEASE'] = @("-O")
      $CMakeDefines['CMAKE_Swift_FLAGS_RELWITHDEBINFO'] = @("-O")
    }

    if ($DebugInfo) {
      if ($UseASM -or $UseC -or $UseCXX) {
        # Prefer `/Z7` over `/ZI`
        $CMakeDefines['CMAKE_MSVC_DEBUG_INFORMATION_FORMAT'] = "Embedded"
        $CMakeDefines['CMAKE_POLICY_DEFAULT_CMP0141'] = "NEW"
        if ($UseASM) {
          # The ASM compiler does not support `/Z7` so we use `/Zi` instead.
          $CMakeDefines['CMAKE_ASM_COMPILE_OPTIONS_MSVC_DEBUG_INFORMATION_FORMAT_Embedded'] = @("-Zi")
        }

        if ($UseGNUDriver) {
          $CMakeDefines['CMAKE_EXE_LINKER_FLAGS'] = @("-Xlinker", "-debug")
          $CMakeDefines['CMAKE_SHARED_LINKER_FLAGS'] = @("-Xlinker", "-debug")
        } else {
          $CMakeDefines['CMAKE_EXE_LINKER_FLAGS'] = @("/debug")
          $CMakeDefines['CMAKE_SHARED_LINKER_FLAGS'] = @("/debug")
        }
      }
    }
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

    $CMakeDefines['CMAKE_ANDROID_API'] = "$AndroidAPILevel"
    $CMakeDefines['CMAKE_ANDROID_ARCH_ABI'] = "$AndroidArchAbi"
    $CMakeDefines['CMAKE_ANDROID_NDK'] = "$AndroidNDKPath"

    if ($UseASM) {
    }

    if ($UseC) {
      $CMakeDefines['CMAKE_C_COMPILER_TARGET'] = $Triple
      $CMakeDefines['CMAKE_C_COMPILER_WORKS'] = "YES"

      $CFLAGS = @("--sysroot=${AndroidSysroot}")
      if ($DebugInfo) {
          $CFLAGS += @("-g", "-gsplit-dwarf")
      }
      $CMakeDefines['CMAKE_C_FLAGS'] = $CFLAGS
    }

    if ($UseCXX) {
      $CMakeDefines['CMAKE_CXX_COMPILER_TARGET'] = $Triple
      $CMakeDefines['CMAKE_CXX_COMPILER_WORKS'] = "YES"
      $CXXFLAGS = @("--sysroot=${AndroidSysroot}")
      if ($DebugInfo) {
          $CFLAGS += @("-g", "-gsplit-dwarf")
      }
      $CMakeDefines['CMAKE_CXX_FLAGS'] = $CXXFLAGS
    }

    if ($UseSwift) {
      if ($UseBuiltCompilers.Contains("Swift")) {
        $CMakeDefines['CMAKE_Swift_COMPILER_WORKS'] = "YES"
      }

      $CMakeDefines['SWIFT_ANDROID_NDK_PATH'] = "$AndroidNDKPath"

      $SWIFTC = if ($UseBuiltCompilers.Contains("Swift")) {
        $SWIFTC = "${Env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/swiftc.exe"
      } else {
        "swiftc.exe"
      }
      $CMakeDefines['CMAKE_Swift_COMPILER'] = $SWIFTC

      $TargetInfo = & $SWIFTC -target $Triple -print-target-info
      $TargetInfo = $TargetInfo | ConvertFrom-Json
      $TargetInfo = $TargetInfo.target
      $CMakeDefines['CMAKE_Swift_COMPILER_TARGET'] = $TargetInfo

      # TODO(compnerd) remove this once we have the early swift-driver
      $CMakeDefines['CMAKE_Swift_COMPILER_USE_OLD_DRIVER'] = "YES"

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

      $CMakeDefines['CMAKE_Swift_FLAGS'] = $SwiftFlags
      # Workaround CMake 3.26+ enabling `-wmo` by default on release builds
      $CMakeDefines['CMAKE_Swift_FLAGS_RELEASE'] = @("-O")
      $CMakeDefines['CMAKE_Swift_FLAGS_RELWITHDEBINFO'] = @("-O")
    }

    $UseBuiltASMCompiler = $UseBuiltCompilers.Contains("ASM")
    $UseBuiltCCompiler = $UseBuiltCompilers.Contains("C")
    $UseBuiltCXXCompiler = $UseBuiltCompilers.Contains("CXX")

    if ($UseBuiltASMCompiler -or $UseBuiltCCompiler -or $UseBuiltCXXCompiler) {
      # Use a built lld linker as the Android's NDK linker might be too old
      # and not support all required relocations needed by the Swift
      # runtime.
      $ld = "${Env:GITHUB_WORKSPACE}/BinaryCache/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/ld.lld"
      $CMakeDefines['CMAKE_SHARED_LINKER_FLAGS'] = @("--ld-path=$ld")
      $CMakeDefines['CMAKE_EXE_LINKER_FLAGS'] = @("--ld-path=$ld")
    }
  }
}

if ($EnableCaching) {
  if ($UseC) {
    $CMakeDefines['CMAKE_C_COMPILER_LAUNCHER'] = "sccache"
  }

  if ($UseCXX) {
    $CMakeDefines['CMAKE_CXX_COMPILER_LAUNCHER'] = "sccache"
  }
}

if ($InstallDir) {
  $CMakeDefines['CMAKE_INSTALL_PREFIX'] = $InstallDir
}

# Generate the project
$cmakeGenerateArgs = @("-B", $BinDir, "-S", $SrcDir, "-G", "Ninja")
if ($CacheScript) {
  $cmakeGenerateArgs += @("-C", $CacheScript)
}

foreach ($Define in ($CMakeDefines.GetEnumerator() | Sort-Object Name)) {
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

Write-Host "Configuring project ${ProjectName}:"
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

foreach ($Target in $BuildTargets) {
  Write-Host "Building target `"$Target`" for project ${ProjectName}:"
  Write-Host "cmake --build $BinDir --target $Target"
  & cmake --build $BinDir --target $Target
  if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed for target `"$Target`" in project ${ProjectName} with exit code $LASTEXITCODE."
  }
}
