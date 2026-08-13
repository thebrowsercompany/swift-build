# Configure a CMake project, mimicking `Build-CMakeProject` from the Swift
# repository's `utils\build.ps1`. See `action.yml` for the documented list of
# differences between this action and `build.ps1`.
#
# This script is invoked by `action.yml`. All inputs are passed via `INPUT_*`
# environment variables (see `action.yml`), so that no GitHub Actions
# `${{ }}` template syntax leaks into this file - GHA does not template `.ps1`
# files, only the inline `run:` block in YAML.

Remove-Item env:\SDKROOT -ErrorAction SilentlyContinue
$ExeSuffix = if ($IsWindows) { ".exe" } else { "" }

function ConvertTo-Bool([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return [System.Convert]::ToBoolean($Value)
}

$ProjectName = $env:INPUT_PROJECT_NAME
$SwiftVersion = $env:INPUT_SWIFT_VERSION
$EnableCaching = ConvertTo-Bool $env:INPUT_ENABLE_CACHING
$DebugInfo = ConvertTo-Bool $env:INPUT_DEBUG_INFO
$BuildOS = $env:INPUT_BUILD_OS
$BuildArch = $env:INPUT_BUILD_ARCH
$OS = $env:INPUT_OS
$Arch = $env:INPUT_ARCH
$SrcDir = $env:INPUT_SRC_DIR
$BinDir = $env:INPUT_BIN_DIR
$InstallDir = $env:INPUT_INSTALL_DIR
$AndroidAPILevel = $env:INPUT_ANDROID_API_LEVEL
$AndroidClangVersion = $env:INPUT_ANDROID_CLANG_VERSION
$NDKPath = $env:INPUT_NDK_PATH
$SwiftSDK = $env:INPUT_SWIFT_SDK_PATH
$CacheScript = $env:INPUT_CACHE_SCRIPT
$UseMSVCHostToolchain = ConvertTo-Bool $env:INPUT_USE_MSVC_HOST_TOOLCHAIN
$UseASM_MASM = ConvertTo-Bool $env:INPUT_USE_ASM_MASM

# `cmake-defines` is a PowerShell hashtable literal (`@{ ... }`) authored at the
# call site. Evaluate it to recover the hashtable; defaults to an empty one.
$CMakeDefines = if ([string]::IsNullOrWhiteSpace($env:INPUT_CMAKE_DEFINES)) {
    @{}
} else {
    Invoke-Expression $env:INPUT_CMAKE_DEFINES
}

function Add-KeyValueIfNew([hashtable]$Hashtable, [string]$Key, [string]$Value) {
    if (-not $Hashtable.Contains($Key)) {
        $Hashtable.Add($Key, $Value)
    }
}

function Add-FlagsDefine([hashtable]$Defines, [string]$Name, [string[]]$Value) {
    $Value = @($Value | Where-Object { $null -ne $_ })
    if ($Value.Count -eq 0) {
        return
    }

    if ($Defines.Contains($Name)) {
        $Defines[$name] = @($Defines[$name]) + $Value
    } else {
        $Defines.Add($Name, $Value)
    }
}

enum DriverStyle {
    CL
    ClangCL
    GNU
    Swift
}

$Assemblers = @{
    Pinned = @{
        Executable       = "clang-cl.exe"
        DriverStyle      = [DriverStyle]::ClangCL
        Flags            = @()
        DebugFlags       = { param([string] $Format)
            if ($Format -eq "dwarf") { @("-clang:-gdwarf") } else { @("-clang:-gcodeview") }
        }
        AssumeFunctional = $false
    }
    Stage1 = @{
        Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage1/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "clang-cl${ExeSuffix}")
        DriverStyle      = [DriverStyle]::ClangCL
        Flags            = @()
        DebugFlags       = { param([string] $Format)
            if ($Format -eq "dwarf") { @("-clang:-gdwarf") } else { @("-clang:-gcodeview") }
        }
        AssumeFunctional = $true
    }
}

$Compilers = @{
    MSVC   = @{
        C   = @{
            Executable       = (Get-Command "cl.exe").Source
            DriverStyle      = [DriverStyle]::CL
            Flags            = @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline", "/Zc:preprocessor")
            DebugFlags       = { param([string] $Format)
                @()
            }
            AssumeFunctional = $false
        }
        CXX = @{
            Executable       = (Get-Command "cl.exe").Source
            DriverStyle      = [DriverStyle]::CL
            Flags            = @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline", "/Zc:preprocessor", "/Zc:__cplusplus")
            DebugFlags       = { param([string] $Format)
                @()
            }
            AssumeFunctional = $false
        }
    }

    Pinned = @{
        C     = @{
            Executable       = (Get-Command "clang-cl.exe").Source
            DriverStyle      = [DriverStyle]::ClangCL
            Flags            = @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline")
            DebugFlags       = { param([string] $Format)
                if ($Format -eq "dwarf") { @("-clang:-gsplit-dwarf") } else { @() }
            }
            AssumeFunctional = $false
        }
        CXX   = @{
            Executable       = (Get-Command "clang-cl.exe").Source
            DriverStyle      = [DriverStyle]::ClangCL
            Flags            = @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline", "/Zc:__cplusplus")
            DebugFlags       = { param([string] $Format)
                if ($Format -eq "dwarf") { @("-clang:-gsplit-dwarf") } else { @() }
            }
            AssumeFunctional = $false
        }
        Swift = @{
            Executable       = (Get-Command "swiftc.exe").Source
            DriverStyle      = [DriverStyle]::Swift
            Flags            = @()
            DebugFlags       = { param([string] $Format)
                @("-g", "-debug-info-format=${Format}")
            }
            AssumeFunctional = $false
        }
    }

    Stage0 = @{
        C      = @{
            Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage0/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "clang-cl${ExeSuffix}")
            DriverStyle      = [DriverStyle]::ClangCL
            Flags            = @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline")
            DebugFlags       = { param([string] $Format)
                if ($Format -eq "dwarf") { @("-clang:-gsplit-dwarf") } else { @() }
            }
            AssumeFunctional = $true
        }
        CXX    = @{
            Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage0/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "clang-cl${ExeSuffix}")
            DriverStyle      = [DriverStyle]::ClangCL
            Flags            = @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline", "/Zc:__cplusplus")
            DebugFlags       = { param([string] $Format)
                if ($Format -eq "dwarf") { @("-clang:-gsplit-dwarf") } else { @() }
            }
            AssumeFunctional = $true
        }
        GNUC   = @{
            Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage0/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "clang${ExeSuffix}")
            DriverStyle      = [DriverStyle]::GNU
            Flags            = @("-fno-stack-protector", "-ffunction-sections", "-fdata-sections", "-fomit-frame-pointer", "-finline-functions")
            DebugFlags       = { param([string] $Format)
                if ($Format -eq "dwarf") { @("-gsplit-dwarf") } else { @("-gcodeview") }
            }
            AssumeFunctional = $true
        }
        GNUCXX = @{
            Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage0/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "clang++${ExeSuffix}")
            DriverStyle      = [DriverStyle]::GNU
            Flags            = @("-fno-stack-protector", "-ffunction-sections", "-fdata-sections", "-fomit-frame-pointer", "-finline-functions")
            DebugFlags       = { param([string] $Format)
                if ($Format -eq "dwarf") { @("-gsplit-dwarf") } else { @("-gcodeview") }
            }
            AssumeFunctional = $true
        }
        Swift  = @{
            Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage0/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "swiftc${ExeSuffix}")
            DriverStyle      = [DriverStyle]::Swift
            Flags            = @()
            DebugFlags       = { param([string] $Format)
                @("-g", "-debug-info-format=${Format}")
            }
            AssumeFunctional = $true
        }
    }

    Stage1 = @{
        C      = @{
            Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage1/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "clang-cl${ExeSuffix}")
            DriverStyle      = [DriverStyle]::ClangCL
            Flags            = @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline")
            DebugFlags       = { param([string] $Format)
                if ($Format -eq "dwarf") { @("-clang:-gsplit-dwarf") } else { @() }
            }
            AssumeFunctional = $true
        }
        CXX    = @{
            Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage1/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "clang-cl${ExeSuffix}")
            DriverStyle      = [DriverStyle]::ClangCL
            Flags            = @("/GS-", "/Gw", "/Gy", "/Oy", "/Oi", "/Zc:inline", "/Zc:__cplusplus")
            DebugFlags       = { param([string] $Format)
                if ($Format -eq "dwarf") { @("-clang:-gsplit-dwarf") } else { @() }
            }
            AssumeFunctional = $true
        }
        GNUC   = @{
            Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage1/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "clang${ExeSuffix}")
            DriverStyle      = [DriverStyle]::GNU
            Flags            = @("-fno-stack-protector", "-ffunction-sections", "-fdata-sections", "-fomit-frame-pointer", "-finline-functions")
            DebugFlags       = { param([string] $Format)
                if ($Format -eq "dwarf") { @("-gsplit-dwarf") } else { @("-gcodeview") }
            }
            AssumeFunctional = $true
        }
        GNUCXX = @{
            Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage1/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "clang++${ExeSuffix}")
            DriverStyle      = [DriverStyle]::GNU
            Flags            = @("-fno-stack-protector", "-ffunction-sections", "-fdata-sections", "-fomit-frame-pointer", "-finline-functions")
            DebugFlags       = { param([string] $Format)
                if ($Format -eq "dwarf") { @("-gsplit-dwarf") } else { @("-gcodeview") }
            }
            AssumeFunctional = $true
        }
        Swift  = @{
            Executable       = [IO.Path]::Combine("${env:GITHUB_WORKSPACE}/BinaryCache/stage1/Library/Developer/Toolchains/${SwiftVersion}+Asserts/usr/bin/", "swiftc${ExeSuffix}")
            DriverStyle      = [DriverStyle]::Swift
            Flags            = @()
            DebugFlags       = { param([string] $Format)
                @("-g", "-debug-info-format=${Format}")
            }
            AssumeFunctional = $true
        }
    }
}

# Mirror `build.ps1`'s `$Compilers.Host` trick: a computed pseudo-set that
# redirects to the host MSVC toolchain or the pinned toolchain depending on
# `$UseMSVCHostToolchain`. This keeps the host-vs-pinned decision in one place so
# call sites can simply select `Host.C` / `Host.CXX`. Note there is no
# `Host.Swift`: Swift always comes from a real stage.
$Compilers.Host = @{
    C   = if ($UseMSVCHostToolchain) { $Compilers.MSVC.C } else { $Compilers.Pinned.C }
    CXX = if ($UseMSVCHostToolchain) { $Compilers.MSVC.CXX } else { $Compilers.Pinned.CXX }
}

# Resolve a dotted selector (e.g. "Pinned.C", "Stage1.GNUCXX", "Host.CXX")
# against a tool table. An empty selector means "tool not used" and resolves to
# $null.
function Resolve-Tool([hashtable]$Root, [string]$Selector) {
    if ([string]::IsNullOrWhiteSpace($Selector)) { return $null }
    $Node = $Root
    foreach ($Part in $Selector.Split('.')) {
        if (($null -eq $Node) -or (-not $Node.Contains($Part))) {
            throw "Invalid tool selector '$Selector': no member '$Part'."
        }
        $Node = $Node[$Part]
    }
    return $Node
}

$Assembler = Resolve-Tool $Assemblers $env:INPUT_ASSEMBLER
$CCompiler = Resolve-Tool $Compilers $env:INPUT_C_COMPILER
$CXXCompiler = Resolve-Tool $Compilers $env:INPUT_CXX_COMPILER
$SwiftCompiler = Resolve-Tool $Compilers $env:INPUT_SWIFT_COMPILER

# Note: On GHA, we do not use the `$Platform` variable as in `build.ps1` so these values
# have to be computed directly here.
$CMakeArch = switch ($OS) {
    'Windows' {
        switch ($Arch) {
            'arm64' { 'ARM64' }
            'amd64' { 'AMD64' }
            'x86' { 'i686' }
            default { throw "Unsupported Windows architecture: $Arch" }
        }
    }
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
            'x86' { "i686-unknown-windows-msvc" }
            'amd64' { "x86_64-unknown-windows-msvc" }
            'arm64' { "aarch64-unknown-windows-msvc" }
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

$UseASM = $null -ne $Assembler
$UseC = $null -ne $CCompiler
$UseCXX = $null -ne $CXXCompiler
$UseSwift = $null -ne $SwiftCompiler
$PlatformDebugFormat = switch ($OS) {
    'Windows' { "codeview" }
    'Android' { "dwarf" }
    default { throw "Unsupported OS: $OS" }
}

function Add-LinkerFlagsDefine([hashtable]$Defines, [string[]]$Value) {
    $Value = $Value | ForEach-Object { "LINKER:$_" }
    Add-FlagsDefine $Defines CMAKE_EXE_LINKER_FLAGS $Value
    Add-FlagsDefine $Defines CMAKE_SHARED_LINKER_FLAGS $Value
}

function Add-SharedLinkerFlagsDefine([hashtable]$Defines, [string[]]$Value) {
    $Value = $Value | ForEach-Object { "LINKER:$_" }
    Add-FlagsDefine $Defines CMAKE_SHARED_LINKER_FLAGS $Value
    Add-FlagsDefine $Defines CMAKE_MODULE_LINKER_FLAGS $Value
}

# Add additional defines (unless already present)
$Defines = $CMakeDefines.Clone()

# Enable CMP0181: Link command-line fragment variables are parsed and re-quoted.
Add-KeyValueIfNew $Defines CMAKE_POLICY_DEFAULT_CMP0181 NEW
# Enable CMP0214: Honor CMAKE_EXE_LINKER_FLAGS for Swift executable targets.
Add-KeyValueIfNew $Defines CMAKE_POLICY_DEFAULT_CMP0214 NEW
# Enable CMP0215: Ninja generators emit Swift modules separately from compilation.
Add-KeyValueIfNew $Defines CMAKE_POLICY_DEFAULT_CMP0215 NEW

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
            Add-KeyValueIfNew $Defines CMAKE_ASM_COMPILER $Assembler.Executable
            Add-KeyValueIfNew $Defines CMAKE_ASM_FLAGS @("--target=$Triple")
            Add-KeyValueIfNew $Defines CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreadedDLL "/MD"

            if ($DebugInfo) {
                # CMake's MSVC_DEBUG_INFORMATION_FORMAT support also applies to ASM
                # targets, but clang-cl-as-ASM does not get a built-in mapping for
                # the Embedded format. Provide the mapping before setting the global
                # CMAKE_MSVC_DEBUG_INFORMATION_FORMAT below.
                Add-FlagsDefine $Defines CMAKE_ASM_COMPILE_OPTIONS_MSVC_DEBUG_INFORMATION_FORMAT_Embedded $(& $Assembler.DebugFlags $PlatformDebugFormat)
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
            Add-KeyValueIfNew $Defines CMAKE_C_COMPILER $CCompiler.Executable
            Add-KeyValueIfNew $Defines CMAKE_C_COMPILER_TARGET $Triple
            Add-FlagsDefine $Defines CMAKE_C_FLAGS $CCompiler.Flags

            if ($DebugInfo) {
                Add-FlagsDefine $Defines CMAKE_C_FLAGS $(& $CCompiler.DebugFlags $PlatformDebugFormat)
            }
        }

        if ($UseCXX) {
            Add-KeyValueIfNew $Defines CMAKE_CXX_COMPILER $CXXCompiler.Executable
            Add-KeyValueIfNew $Defines CMAKE_CXX_COMPILER_TARGET $Triple
            Add-FlagsDefine $Defines CMAKE_CXX_FLAGS $CXXCompiler.Flags

            # With clang-cl, CMake generates MSVC-style archive rules (/nologo /out:...).
            # If llvm-lib.exe is not found next to clang-cl.exe, CMake can fall back to
            # whatever 'ar' is on PATH (e.g. the installed toolchain's POSIX ar.exe),
            # causing a flags mismatch.  Explicitly pin CMAKE_AR to llvm-lib.exe from
            # the compiler bin directory so the right tool is always selected.
            if ($CXXCompiler.DriverStyle -eq [DriverStyle]::ClangCL) {
                $librarian = [IO.Path]::Combine([IO.Path]::GetDirectoryName($CXXCompiler.Executable), "llvm-lib.exe")
                if (Test-Path $librarian) {
                    Add-KeyValueIfNew $Defines CMAKE_AR $librarian
                }
            }

            if ($DebugInfo) {
                Add-FlagsDefine $Defines CMAKE_CXX_FLAGS $(& $CXXCompiler.DebugFlags $PlatformDebugFormat)
            }
        }

        if ($UseSwift) {
            if ($SwiftCompiler.AssumeFunctional) {
                Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_WORKS "YES"
            }

            Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER $SwiftCompiler.Executable
            Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_TARGET $Triple
            # Skip compiler ID detection: avoids compiling+scanning a multi-MB test binary on every configure.
            Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_ID "Apple"

            Add-FlagsDefine $Defines CMAKE_Swift_FLAGS $SwiftCompiler.Flags
            if ($SwiftSDK) {
                Add-FlagsDefine $Defines CMAKE_Swift_FLAGS @("-sdk", $SwiftSDK)
            }
            if ($DebugInfo) {
                Add-FlagsDefine $Defines CMAKE_Swift_FLAGS $(& $SwiftCompiler.DebugFlags $PlatformDebugFormat)
            } else {
                Add-FlagsDefine $Defines CMAKE_Swift_FLAGS @("-gnone")
            }

            # CMake 3.30+ passes all linker flags to Swift as the linker driver,
            # including those from the internal CMake modules files, without
            # a `-Xlinker` prefix. This causes build failures as Swift cannot
            # parse linker flags.
            # Overwrite the release linker flags to be empty to avoid this.
            Add-KeyValueIfNew $Defines CMAKE_EXE_LINKER_FLAGS_RELEASE ""
            Add-KeyValueIfNew $Defines CMAKE_SHARED_LINKER_FLAGS_RELEASE ""

            # Workaround CMake 3.26+ enabling `-wmo` by default on release builds
            Add-FlagsDefine $Defines CMAKE_Swift_FLAGS_RELEASE "-O"
            Add-FlagsDefine $Defines CMAKE_Swift_FLAGS_RELWITHDEBINFO "-O"
        }

        Add-LinkerFlagsDefine $Defines @("/INCREMENTAL:NO", "/OPT:REF", "/OPT:ICF")
        Add-SharedLinkerFlagsDefine $Defines @("/MANIFEST:NO")
        Add-KeyValueIfNew $Defines CMAKE_USER_MAKE_RULES_OVERRIDE `
            "${env:GITHUB_WORKSPACE}\SourceCache\ci-build\.github\actions\configure-cmake-project\windows-clang-overrides.cmake"

        if ($DebugInfo) {
            if ($UseASM -or $UseC -or $UseCXX) {
                # Prefer `/Z7` over `/ZI`
                # By setting the debug information format, the appropriate C/C++
                # flags will be set for codeview debug information format so there
                # is no need to set them explicitly above.
                Add-KeyValueIfNew $Defines CMAKE_MSVC_DEBUG_INFORMATION_FORMAT Embedded
                Add-KeyValueIfNew $Defines CMAKE_POLICY_DEFAULT_CMP0141 NEW
                Add-LinkerFlagsDefine $Defines @("/DEBUG")
            }
        }
    }

    'Android' {
        # Note: On GHA, we do not use the `$Platform` variable as in `build.ps1` so these values
        # have to be computed directly here.
        $AndroidArchABI = switch ($Arch) {
            'i686' { "x86" }
            'x86_64' { "x86_64" }
            'armv7' { "armeabi-v7a" }
            'arm64' { "arm64-v8a" }
            default { throw "Unsupported architecture: $Arch" }
        }
        $AndroidArchLLVM = switch ($BuildArch) {
            'amd64' { "x86_64" }
            'arm64' { "aarch64" }
            default { throw "Unsupported architecture: $BuildArch" }
        }
        $AndroidNDKPath = $NDKPath
        $AndroidPrebuiltRoot = "$AndroidNDKPath\toolchains\llvm\prebuilt\$($BuildOS.ToLowerInvariant())-$($AndroidArchLLVM)"
        $AndroidSysroot = "$AndroidPrebuiltRoot\sysroot"

        Add-KeyValueIfNew $Defines CMAKE_ANDROID_API "$AndroidAPILevel"
        Add-KeyValueIfNew $Defines CMAKE_ANDROID_ARCH_ABI "$AndroidArchABI"
        Add-KeyValueIfNew $Defines CMAKE_ANDROID_NDK "$AndroidNDKPath"
        Add-KeyValueIfNew $Defines CMAKE_SYSROOT "$AndroidSysroot"

        if ($UseASM) {
        }

        if ($UseC) {
            Add-KeyValueIfNew $Defines CMAKE_C_COMPILER_TARGET $Triple
            Add-FlagsDefine $Defines CMAKE_C_FLAGS $CCompiler.Flags
            if ($DebugInfo) {
                Add-FlagsDefine $Defines CMAKE_C_FLAGS $(& $CCompiler.DebugFlags $PlatformDebugFormat)
            }
        }

        if ($UseCXX) {
            Add-KeyValueIfNew $Defines CMAKE_CXX_COMPILER_TARGET $Triple
            Add-FlagsDefine $Defines CMAKE_CXX_FLAGS $CXXCompiler.Flags
            if ($DebugInfo) {
                Add-FlagsDefine $Defines CMAKE_CXX_FLAGS $(& $CXXCompiler.DebugFlags $PlatformDebugFormat)
            }
        }

        if ($UseSwift) {
            if ($SwiftCompiler.AssumeFunctional) {
                Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_WORKS "YES"
            }

            # FIXME(compnerd) remove this once the old runtimes build path is removed.
            Add-KeyValueIfNew $Defines SWIFT_ANDROID_NDK_PATH "$AndroidNDKPath"

            Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER $SwiftCompiler.Executable
            Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_TARGET $Triple
            # Skip compiler ID detection: avoids compiling+scanning a multi-MB test binary on every configure.
            Add-KeyValueIfNew $Defines CMAKE_Swift_COMPILER_ID "Apple"

            Add-FlagsDefine $Defines CMAKE_Swift_FLAGS $SwiftCompiler.Flags
            if ($SwiftSDK) {
                # TODO: CMake does not yet have support for passing `CMAKE_SYSROOT`
                # to the Swift compiler yet.  Once we have that, we can drop
                # `-sysroot $AndroidSysroot` here.
                Add-FlagsDefine $Defines CMAKE_Swift_FLAGS @("-sdk", $SwiftSDK, "-sysroot", $AndroidSysroot)
            }
            if ($DebugInfo) {
                Add-FlagsDefine $Defines CMAKE_Swift_FLAGS $(& $SwiftCompiler.DebugFlags $PlatformDebugFormat)
            } else {
                Add-FlagsDefine $Defines CMAKE_Swift_FLAGS @("-gnone")
            }

            Add-FlagsDefine $Defines CMAKE_Swift_FLAGS @(
                "-Xclang-linker", "-target", "-Xclang-linker", $Triple,
                "-Xclang-linker", "--sysroot", "-Xclang-linker", $AndroidSysroot,
                "-Xclang-linker", "-resource-dir", "-Xclang-linker", "${AndroidPrebuiltRoot}\lib\clang\${AndroidClangVersion}"
            )
        }

        if (($UseASM -and $Assembler.AssumeFunctional) -or ($UseC -and $CCompiler.AssumeFunctional) -or ($UseCXX -and $CXXCompiler.AssumeFunctional)) {
            # Use a built lld linker as the Android's NDK linker might be too old
            # and not support all required relocations needed by the Swift
            # runtime.
            $Executable = if ($UseC) {
                $CCompiler.Executable
            } elseif ($UseCXX) {
                $CXXCompiler.Executable
            } elseif ($UseASM) {
                $Assembler.Executable
            }
            $ld = Join-Path -Path (Split-Path $Executable) -ChildPath "ld.lld"
            if ($UseSwift) {
                # The Android NDK injects `-Wl,<arg>` flags into
                # `CMAKE_*_LINKER_FLAGS` via `CMAKE_*_LINKER_FLAGS_INIT` variables.
                # CMake 3.30+ passes these to the Swift driver, which doesn't
                # understand the `-Wl,` syntax. Pre-set the flags in a portable form
                # (`-Xlinker <arg>`) from the command line as this takes precedence
                # over the NDK's `*_INIT` mechanism.
                #
                # `--ld-path` and `-Qunused-arguments` are Clang driver flags,
                # handled via `CMAKE_PROJECT_INCLUDE` with a `LINK_LANGUAGE` guard,
                # so they do not affect Swift linking.
                $AndroidLinkerFlags = @(
                    "-Xlinker", "--build-id=sha1",
                    "-Xlinker", "--no-rosegment",
                    "-Xlinker", "--no-undefined-version",
                    "-Xlinker", "--fatal-warnings",
                    "-Xlinker", "--gc-sections",
                    "-Xlinker", "--no-undefined"
                )
                Add-FlagsDefine $Defines CMAKE_SHARED_LINKER_FLAGS $AndroidLinkerFlags
                Add-FlagsDefine $Defines CMAKE_EXE_LINKER_FLAGS ($AndroidLinkerFlags + @("-Xlinker", "--gc-sections"))
                Add-FlagsDefine $Defines CMAKE_MODULE_LINKER_FLAGS $AndroidLinkerFlags
                Add-KeyValueIfNew $Defines SWIFT_ANDROID_LD_PATH $ld
                Add-KeyValueIfNew $Defines CMAKE_PROJECT_INCLUDE `
                    "${env:GITHUB_WORKSPACE}\SourceCache\ci-build\.github\actions\configure-cmake-project\android-overrides.cmake"
            } else {
                # Clang Runtime explicitly sets linker flags for every target,
                # making the `add_link_options()` approach via
                # `CMAKE_PROJECT_INCLUDE` not viable. Since the problem that the
                # above block aims to solve only concerns projects that use Swift,
                # we can get away with just overriding `CMAKE_*_LINKER_FLAGS` for
                # non-Swift projects.
                Add-FlagsDefine $Defines CMAKE_SHARED_LINKER_FLAGS "--ld-path=$ld"
                Add-FlagsDefine $Defines CMAKE_EXE_LINKER_FLAGS "--ld-path=$ld"
            }
        }

        # TODO(compnerd) we should understand why CMake does not understand
        # that the object file format is ELF when targeting Android on Windows.
        # This indication allows it to understand that it can use `chrpath` to
        # change the RPATH on the dynamic libraries.
        Add-FlagsDefine $Defines CMAKE_EXECUTABLE_FORMAT "ELF"
    }
}

# Note: In build.ps1, sccache is no longer supported.
if ($EnableCaching -and $OS -ne "Android") {
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
                # Escape the quote so it makes it through. PowerShell 5 and Core
                # handle quotes differently, so we need to check the version.
                $quote = if ($PSEdition -eq "Core") { '"' } else { '\"' }
                $Value += "$quote$ArgWithForwardSlashes$quote"
            } else {
                $Value += $ArgWithForwardSlashes
            }
        }
    }

    $cmakeGenerateArgs += @("-D", "$($Define.Key)=$Value")
}

# Note: On GHA, we do a "pretty-print" of the cmake command for
# debugging purposes and call cmake directly.
Write-Host "ℹ️ Configuring project ${ProjectName}:"
Write-Host 'cmake `'
for ($i = 0; $i -lt $cmakeGenerateArgs.Length; $i += 1) {
    $Arg = $cmakeGenerateArgs[$i]
    if ($Arg -match '\s') {
        Write-Host "  `'$Arg`'" -NoNewline
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
