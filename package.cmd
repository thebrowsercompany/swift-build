:: Copyright 2021 Saleem Abdulrasool <compnerd@compnerd.org>

set SourceCache=S:\SourceCache
set ToolchainInstallRoot=S:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain
set PlatformInstallRoot=S:\Library\Developer\Platforms\Windows.platform
set SDKInstallRoot=%PlatformInstallRoot%\Developer\SDKs\Windows.sdk

FOR %%M In (_InternalSwiftScan, _InternalSwiftSyntaxParser) DO (
  copy /Y %ToolchainInstallRoot%\usr\lib\%%M.lib %ToolchainInstallRoot%\usr\lib\swift\windows\%%M.lib
)

FOR %%M IN (Block, dispatch, os) DO (
  md %SDKInstallRoot%\usr\lib\swift\%%M
  copy /Y %SDKInstallRoot%\usr\include\%%M %SDKInstallRoot%\usr\lib\swift\%%M\
)

FOR %%M IN (_Concurrency, _Differentiation, _Distributed, CRT, Swift, SwiftOnoneSupport, WinSDK, BlocksRuntime, dispatch, swiftDispatch, Foundation, FoundationNetworking, FoundationXML) DO (
  copy /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.lib %SDKInstallRoot%\usr\lib\swift\windows\%%M.lib
)

FOR %%M IN (_Concurrency, _Differentiation, _Distributed, CRT, Swift, SwiftOnoneSupport, WinSDK) DO (
  md %SDKInstallRoot%\usr\lib\swift\windows\%%M.swiftmodule
  copy /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule %SDKInstallRoot%\usr\lib\swift\windows\%%M.swiftmodule
)

FOR %%M IN (Dispatch, Foundation, FoundationNetworking, FoundationXML) DO (
  move /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule\x86_64-unknown-windows-msvc.swiftdoc %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftdoc
  move /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule\x86_64-unknown-windows-msvc.swiftmodule %SDKInstallRoot%\usr\lib\swift\windows\x86_64\_%%M.swiftmodule
  rd /Q %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule
  move /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\_%%M.swiftmodule %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule
)

msbuild %SourceCache%\swift-installer-scripts\platforms\Windows\toolchain.wixproj ^
  -p:RunWixToolsOutOfProc=true                                                    ^
  -p:OutputPath=S:\b\msi\                                                         ^
  -p:IntermediateOutputPath=S:\b\toolchain\                                       ^
  -p:TOOLCHAIN_ROOT=%ToolchainInstallRoot%\

msbuild %SourceCache%\swift-installer-scripts\platforms\Windows\CustomActions\SwiftInstaller\SwiftInstaller.vcxproj -t:restore
msbuild %SourceCache%\swift-installer-scripts\platforms\Windows\sdk.wixproj     ^
  -p:RunWixToolsOutOfProc=true                                                  ^
  -p:OutputPath=S:\b\msi\                                                       ^
  -p:IntermediateOutputPath=S:\b\sdk\                                           ^
  -p:PlatformToolset=v143                                                       ^
  -p:PLATFORM_ROOT=%PlatformInstallRoot%\                                       ^
  -p:SDK_ROOT=%SDKInstallRoot%\                                                 ^
  -p:SWIFT_SOURCE_DIR=%SourceCache%\swift\

msbuild %SourceCache%\swift-installer-scripts\platforms\Windows\runtime.wixproj ^
  -p:RunWixToolsOutOfProc=true                                                  ^
  -p:OutputPath=S:\b\msi\                                                       ^
  -p:IntermediateOutputPath=S:\b\runtime\                                       ^
  -p:SDK_ROOT=%SDKInstallRoot%\

msbuild %SourceCache%\swift-installer-scripts\platforms\Windows\icu.wixproj     ^
  -p:RunWixToolsOutOfProc=true                                                  ^
  -p:OutputPath=S:\b\msi\                                                       ^
  -p:IntermediateOutputPath=S:\b\icu\                                           ^
  -p:ProductVersion=69.1                                                        ^
  -p:ProductVersionMajor=69                                                     ^
  -p:ICU_ROOT=S:\

msbuild %SourceCache%\swift-installer-scripts\platforms\Windows\devtools.wixproj  ^
  -p:RunWixToolsOutOfProc=true                                                    ^
  -p:OutputPath=S:\b\msi\                                                         ^
  -p:IntermediateOutputPath=S:\b\devtools\                                        ^
  -p:DEVTOOLS_ROOT=%ToolchainInstallRoot%\

msbuild %SourceCache%\swift-installer-scripts\platforms\Windows\installer.wixproj ^
  -p:RunWixToolsOutOfProc=true                                                    ^
  -p:OutputPath=S:\b\                                                             ^
  -p:IntermediateOutputPath=S:\b\installer\                                       ^
  -p:MSI_LOCATION=S:\b\msi\
