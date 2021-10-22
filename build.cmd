:: Copyright 2020 Saleem Abdulrasool <compnerd@compnerd.org>

set SourceCache=S:\SourceCache
set ToolchainInstallRoot=S:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain
set PlatformInstallRoot=S:\Library\Developer\Platforms\Windows.platform
set SDKInstallRoot=%PlatformInstallRoot%\Developer\SDKs\Windows.sdk

:: zlib
cmake                                                                           ^
  -B S:\b\zlib-1.2.11                                                           ^
  -D BUILD_SHARED_LIBS=NO                                                       ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_MT=mt                                                                ^
  -D CMAKE_INSTALL_PREFIX=S:\Library\zlib-1.2.11\usr                            ^
  -D SKIP_INSTALL_FILES=YES                                                     ^
  -G Ninja                                                                      ^
  -S %SourceCache%\zlib || (exit /b)
cmake --build S:\b\zlib-1.2.11 || (exit /b)
cmake --build S:\b\zlib-1.2.11 --target install || (exit /b)

:: libxml2
cmake                                                                           ^
  -B S:\b\libxml2-2.9.12                                                        ^
  -D BUILD_SHARED_LIBS=NO                                                       ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_MT=mt                                                                ^
  -D CMAKE_INSTALL_PREFIX=S:\Library\libxml2-2.9.12\usr                         ^
  -D LIBXML2_WITH_ICONV=NO                                                      ^
  -D LIBXML2_WITH_ICU=NO                                                        ^
  -D LIBXML2_WITH_LZMA=NO                                                       ^
  -D LIBXML2_WITH_PYTHON=NO                                                     ^
  -D LIBXML2_WITH_TESTS=NO                                                      ^
  -D LIBXML2_WITH_THREADS=YES                                                   ^
  -D LIBXML2_WITH_ZLIB=NO                                                       ^
  -G Ninja                                                                      ^
  -S %SourceCache%\libxml2 || (exit /b)
cmake --build S:\b\libxml2-2.9.12 || (exit /b)
cmake --build S:\b\libxml2-2.9.12 --target install || (exit /b)

:: curl
cmake                                                                           ^
  -B S:\b\curl-7.77.0                                                           ^
  -D BUILD_SHARED_LIBS=NO                                                       ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_MT=mt                                                                ^
  -D CMAKE_INSTALL_PREFIX=S:\Library\curl-7.77.0\usr                            ^
  -D BUILD_CURL_EXE=NO                                                          ^
  -D CMAKE_USE_OPENSSL=NO                                                       ^
  -D CURL_CA_PATH=none                                                          ^
  -D CMAKE_USE_SCHANNEL=YES                                                     ^
  -D CMAKE_USE_LIBSSH2=NO                                                       ^
  -D HAVE_POLL_FINE=NO                                                          ^
  -D CURL_DISABLE_LDAP=YES                                                      ^
  -D CURL_DISABLE_LDAPS=YES                                                     ^
  -D CURL_DISABLE_TELNET=YES                                                    ^
  -D CURL_DISABLE_DICT=YES                                                      ^
  -D CURL_DISABLE_FILE=YES                                                      ^
  -D CURL_DISABLE_TFTP=YES                                                      ^
  -D CURL_DISABLE_RTSP=YES                                                      ^
  -D CURL_DISABLE_PROXY=YES                                                     ^
  -D CURL_DISABLE_POP3=YES                                                      ^
  -D CURL_DISABLE_IMAP=YES                                                      ^
  -D CURL_DISABLE_SMTP=YES                                                      ^
  -D CURL_DISABLE_GOPHER=YES                                                    ^
  -D CURL_ZLIB=YES                                                              ^
  -D ENABLE_UNIX_SOCKETS=NO                                                     ^
  -D ENABLE_THREADED_RESOLVER=NO                                                ^
  -D ZLIB_ROOT=S:\Library\zlib-1.2.11\usr                                       ^
  -D ZLIB_LIBRARY=S:\Library\zlib-1.2.11\usr\lib\zlibstatic.lib                 ^
  -G Ninja                                                                      ^
  -S %SourceCache%\curl || (exit /b)
cmake --build S:\b\curl-7.77.0 || (exit /b)
cmake --build S:\b\curl-7.77.0 --target install || (exit /b)

:: icu
IF NOT EXIST %SourceCache%\icu\icu4c\CMakeLists.txt copy %SourceCache%\swift-build\cmake\ICU\CMakeLists69.txt %SourceCache%\icu\icu4c\CMakeLists.txt
cmake                                                                           ^
  -B S:\b\icu-69.1                                                              ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_MT=mt                                                                ^
  -D CMAKE_INSTALL_PREFIX=S:\Library\icu-69.1\usr                               ^
  -D BUILD_TOOLS=YES                                                            ^
  -G Ninja                                                                      ^
  -S %SourceCache%\icu\icu4c || (exit /b)
cmake --build S:\b\icu-69.1 || (exit /b)
cmake --build S:\b\icu-69.1 --target install || (exit /b)

:: sqlite
md S:\var\cache
IF NOT EXIST S:\var\cache\sqlite-amalgamation-3360000.zip curl -sL https://sqlite.org/2021/sqlite-amalgamation-3360000.zip -o S:\var\cache\sqlite-amalgamation-3360000.zip
IF NOT EXIST %SourceCache%\sqlite-3.36.0  (
  md %SourceCache%\sqlite-3.36.0
  "%ProgramFiles%\Git\usr\bin\unzip.exe" -o S:\var\cache\sqlite-amalgamation-3360000.zip -d %SourceCache%\sqlite-3.36.0
  copy /Y %SourceCache%\swift-build\cmake\SQLite\CMakeLists.txt %SourceCache%\sqlite-3.36.0\
)
cmake                                                                           ^
  -B S:\b\sqlite-3.36.0                                                         ^
  -D BUILD_SHARED_LIBS=NO                                                       ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_INSTALL_PREFIX=S:\Library\sqlite-3.36.0\usr                          ^
  -D CMAKE_MT=mt                                                                ^
  -G Ninja                                                                      ^
  -S %SourceCache%\sqlite-3.36.0 || (exit /b)
cmake --build S:\b\sqlite-3.36.0 || (exit /b)
cmake --build S:\b\sqlite-3.36.0 --target install || (exit /b)

:: toolchain
cmake                                                                           ^
  -B S:\b\1                                                                     ^
  -C %SourceCache%\swift\cmake\caches\Windows-x86_64.cmake                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -D CMAKE_MT=mt                                                                ^
  -D LLVM_ENABLE_PDB=YES                                                        ^
  -D LLVM_EXTERNAL_CMARK_SOURCE_DIR=%SourceCache%\cmark                         ^
  -D LLVM_EXTERNAL_SWIFT_SOURCE_DIR=%SourceCache%\swift                         ^
  -D SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=YES                                  ^
  -D SWIFT_PATH_TO_LIBDISPATCH_SOURCE=%SourceCache%\swift-corelibs-libdispatch  ^
  -D SWIFT_WINDOWS_x86_64_ICU_I18N=S:\Library\icu-69.1\usr\lib\icuin69.lib      ^
  -D SWIFT_WINDOWS_x86_64_ICU_I18N_INCLUDE=S:\Library\icu-69.1\usr\include      ^
  -D SWIFT_WINDOWS_x86_64_ICU_UC=S:\Library\icu-69.1\usr\lib\icuuc69.lib        ^
  -D SWIFT_WINDOWS_x86_64_ICU_UC_INCLUDE=S:\Library\icu-69.1\usr\include        ^
  -G Ninja                                                                      ^
  -S %SourceCache%\llvm-project\llvm || (exit /b)

cmake --build S:\b\1 || (exit /b)
cmake --build S:\b\1 --target install || (exit /b)

:: Restructure Internal Modules
FOR %%M IN (_InternalSwiftScan, _InternalSwiftSyntaxParser) DO (
  dir "%ToolchainInstallRoot%\usr\include\%%M" >NUL 2>NUL
  IF NOT ERRORLEVEL 1 ( rd /s /q "%ToolchainInstallRoot%\usr\include\%%M" )
  move /Y %ToolchainInstallRoot%\usr\lib\%%M %ToolchainInstallRoot%\usr\include
  move %ToolchainInstallRoot%\usr\lib\swift\windows\%%M.lib %ToolchainInstallRoot%\usr\lib
)

:: runtime
cmake                                                                           ^
  -B S:\b\100                                                                   ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_MT=mt                                                                ^
  -D LLVM_HOST_TRIPLE=x86_64-unknown-windows-msvc                               ^
  -G Ninja                                                                      ^
  -S %SourceCache%\llvm-project\llvm || (exit /b)

cmake                                                                           ^
  -B S:\b\101                                                                   ^
  -C %SourceCache%\swift\cmake\caches\Runtime-Windows-x86_64.cmake              ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe                                   ^
  -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%SDKInstallRoot%\usr                                  ^
  -D CMAKE_MT=mt                                                                ^
  -D LLVM_DIR=S:\b\100\lib\cmake\llvm                                           ^
  -D SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=YES                                  ^
  -D SWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=YES                   ^
  -D SWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED=YES                                  ^
  -D SWIFT_NATIVE_SWIFT_TOOLS_PATH=S:\b\1\bin                                   ^
  -D SWIFT_WINDOWS_x86_64_ICU_I18N=S:\Library\icu-69.1\usr\lib\icuin69.lib      ^
  -D SWIFT_WINDOWS_x86_64_ICU_I18N_INCLUDE=S:\Library\icu-69.1\usr\include      ^
  -D SWIFT_WINDOWS_x86_64_ICU_UC=S:\Library\icu-69.1\usr\lib\icuuc69.lib        ^
  -D SWIFT_WINDOWS_x86_64_ICU_UC_INCLUDE=S:\Library\icu-69.1\usr\include        ^
  -D SWIFT_PATH_TO_LIBDISPATCH_SOURCE=%SourceCache%\swift-corelibs-libdispatch  ^
  -G Ninja                                                                      ^
  -S %SourceCache%\swift || (exit /b)

cmake --build S:\b\101 || (exit /b)
cmake --build S:\b\101 --target install || (exit /b)

:: Restructure Core Modules
FOR %%M IN (_Concurrency, _Differentiation, _Distributed, CRT, Swift, SwiftOnoneSupport, WinSDK) DO (
  dir "%SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule\." >NUL 2>NUL
  IF NOT ERRORLEVEL 1 ( rd /s /q %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule )
  move /Y %SDKInstallRoot%\usr\lib\swift\windows\%%M.swiftmodule %SDKInstallRoot%\usr\lib\swift\windows\x86_64
)

:: SDKSettings.plist
"%ProgramFiles(x86)%\Microsoft Visual Studio\Shared\Python39_64\python.exe" -c "import plistlib; print(str(plistlib.dumps({ 'DefaultProperties': { 'DEFAULT_USE_RUNTIME': 'MD' } }), encoding='utf-8'))" > %SDKInstallRoot%\SDKSettings.plist

:: Windows x86 Runtime
:: cmake                                                                           ^
::   -B S:\b\102                                                                   ^
::   -C %SourceCache%\swift\cmake\caches\Runtime-Windows-i686.cmake                ^
::   -D CMAKE_BUILD_TYPE=Release                                                   ^
::   -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe                                   ^
::   -D CMAKE_C_COMPILER_TARGET=i686-unknown-windows-msvc                          ^
::   -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe                                 ^
::   -D CMAKE_CXX_COMPILER_TARGET=i686-unknown-windows-msvc                        ^
::   -D CMAKE_INSTALL_PREFIX=%SDKInstallRoot%\usr                                  ^
::   -D CMAKE_MT=mt                                                                ^
::   -D LLVM_DIR=S:\b\100\lib\cmake\llvm                                           ^
::   -D SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=YES                                  ^
::   -D SWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=YES                   ^
::   -D SWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED=YES                                  ^
::   -D SWIFT_NATIVE_SWIFT_TOOLS_PATH=S:\b\1\bin                                   ^
::   -D SWIFT_WINDOWS_i686_ICU_I18N=S:\Library\icu-69.1-32\usr\lib\icuin69.lib     ^
::   -D SWIFT_WINDOWS_i686_ICU_I18N_INCLUDE=S:\Library\icu-69.1-32\usr\include     ^
::   -D SWIFT_WINDOWS_i686_ICU_UC=S:\Library\icu-69.1-32\usr\lib\icuuc69.lib       ^
::   -D SWIFT_WINDOWS_i686_ICU_UC_INCLUDE=S:\Library\icu-69.1-32\usr\include       ^
::   -D SWIFT_PATH_TO_LIBDISPATCH_SOURCE=%SourceCache%\swift-corelibs-libdispatch  ^
::   -G Ninja                                                                      ^
::   -S %SourceCache%\swift || (exit /b)

:: Windows ARM64 Runtime
:: cmake                                                                           ^
::   -B S:\b\104                                                                   ^
::   -C %SourceCache%\swift\cmake\caches\Runtime-Windows-aarch64.cmake             ^
::   -D CMAKE_BUILD_TYPE=Release                                                   ^
::   -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe                                   ^
::   -D CMAKE_C_COMPILER_TARGET=aarch64-unknown-windows-msvc                       ^
::   -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe                                 ^
::   -D CMAKE_CXX_COMPILER_TARGET=aarch64-unknown-windows-msvc                     ^
::   -D CMAKE_INSTALL_PREFIX=%SDKInstallRoot%\usr                                  ^
::   -D CMAKE_MT=mt                                                                ^
::   -D LLVM_DIR=S:\b\100\lib\cmake\llvm                                           ^
::   -D SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=YES                                  ^
::   -D SWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=YES                   ^
::   -D SWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED=YES                                  ^
::   -D SWIFT_NATIVE_SWIFT_TOOLS_PATH=S:\b\1\bin                                   ^
::   -D SWIFT_WINDOWS_aarch64_ICU_I18N=S:\Library\icu-69.1-arm64\usr\lib\icuin69.lib  ^
::   -D SWIFT_WINDOWS_aarch64_ICU_I18N_INCLUDE=S:\Library\icu-69.1-arm64\usr\include  ^
::   -D SWIFT_WINDOWS_aarch64_ICU_UC=S:\Library\icu-69.1-arm64\usr\lib\icuuc69.lib    ^
::   -D SWIFT_WINDOWS_aarch64_ICU_UC_INCLUDE=S:\Library\icu-69.1-arm64\usr\include    ^
::   -D SWIFT_PATH_TO_LIBDISPATCH_SOURCE=%SourceCache%\swift-corelibs-libdispatch  ^
::   -G Ninja                                                                      ^
::   -S %SourceCache%\swift || (exit /b)

:: swift-corelibs-libdispatch
cmake                                                                           ^
  -B S:\b\2                                                                     ^
  -D BUILD_TESTING=NO                                                           ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe                                   ^
  -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe                                 ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=S:\Library\Developer\Platforms\Windows.platform\Developer\SDKs\Windows.sdk\usr ^
  -D CMAKE_MT=mt                                                                ^
  -D ENABLE_SWIFT=YES                                                           ^
  -G Ninja                                                                      ^
  -S %SourceCache%\swift-corelibs-libdispatch || (exit /b)

cmake --build S:\b\2 || (exit /b)

:: Clean up any existing installation
dir "%SDKInstallRoot%\usr\lib\swift\windows\x86_64\Dispatch.swiftmodule\." >NUL 2>NUL
IF NOT ERRORLEVEL 1 ( rd /s /q %SDKInstallRoot%\usr\lib\swift\windows\x86_64\Dispatch.swiftmodule )

cmake --build S:\b\2 --target install || (exit /b)

:: Restructure BlocksRuntime, dispatch headers
FOR %%M IN (Block, dispatch, os) DO (
  rd /s /q %SDKInstallRoot%\usr\include\%%M
  move /Y %SDKInstallRoot%\usr\lib\swift\%%M %SDKInstallRoot%\usr\include\
)

:: Restructure Import Libraries
FOR %%M IN (BlocksRuntime, dispatch, swiftDispatch) DO (
  move /Y %SDKInstallRoot%\usr\lib\swift\windows\%%M.lib %SDKInstallRoot%\usr\lib\swift\windows\x86_64
)

:: Restructure Module
move /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\Dispatch.swiftmodule %SDKInstallRoot%\usr\lib\swift\windows\x86_64\_.swiftmodule
md %SDKInstallRoot%\usr\lib\swift\windows\x86_64\Dispatch.swiftmodule
move /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\_.swiftmodule %SDKInstallRoot%\usr\lib\swift\windows\x86_64\Dispatch.swiftmodule\x86_64-unknown-windows-msvc.swiftmodule
move /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\Dispatch.swiftdoc %SDKInstallRoot%\usr\lib\swift\windows\x86_64\Dispatch.swiftmodule\x86_64-unknown-windows-msvc.swiftdoc

:: swift-corelibs-foundation
cmake                                                                           ^
  -B S:\b\3                                                                     ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe                                   ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%SDKInstallRoot%\usr                                  ^
  -D CMAKE_MT=mt                                                                ^
  -D CURL_DIR=S:\Library\curl-7.77.0\usr\lib\cmake\CURL                         ^
  -D ICU_I18N_LIBRARY_RELEASE=S:\Library\icu-69.1\usr\lib\icuin69.lib           ^
  -D ICU_ROOT=S:\Library\icu-69.1\usr                                           ^
  -D ICU_UC_LIBRARY_RELEASE=S:\Library\icu-69.1\usr\lib\icuuc69.lib             ^
  -D LIBXML2_LIBRARY=S:\Library\libxml2-2.9.12\usr\lib\libxml2s.lib             ^
  -D LIBXML2_INCLUDE_DIR=S:\Library\libxml2-2.9.12\usr\include\libxml2          ^
  -D LIBXML2_DEFINITIONS="/DLIBXML_STATIC"                                      ^
  -D ZLIB_LIBRARY=S:\Library\zlib-1.2.11\usr\lib\zlibstatic.lib                 ^
  -D ZLIB_INCLUDE_DIR=S:\Library\zlib-1.2.11\usr\include                        ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D ENABLE_TESTING=NO                                                          ^
  -G Ninja                                                                      ^
  -S %SourceCache%\swift-corelibs-foundation || (exit /b)

cmake --build S:\b\3 || (exit /b)

:: Clean up any existing installation
FOR %%M IN (Foundation, FoundationNetworking, FoundationXML) DO (
  dir "%SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule\."
  IF NOT ERRORLEVEL 1 ( rd /s /q %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule )
)

cmake --build S:\b\3 --target install || (exit /b)

:: Remove CoreFoundation Headers
FOR %%M IN (CoreFoundation, CFXMLInterface, CFURLSessionInterface) DO (
  rd /s /q %SDKInstallRoot%\usr\lib\swift\%%M
)

:: Restructure Import Libraries, Modules
FOR %%M IN (Foundation, FoundationNetworking, FoundationXML) DO (
  move /Y %SDKInstallRoot%\usr\lib\swift\windows\%%M.lib %SDKInstallRoot%\usr\lib\swift\windows\x86_64

  move /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule %SDKInstallRoot%\usr\lib\swift\windows\x86_64\_.swiftmodule
  md %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule
  move /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\_.swiftmodule %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule\x86_64-unknown-windows-msvc.swiftmodule
  move /Y %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftdoc %SDKInstallRoot%\usr\lib\swift\windows\x86_64\%%M.swiftmodule\x86_64-unknown-windows-msvc.swiftdoc
)

:: swift-corelibs-xctest
cmake                                                                           ^
  -B S:\b\4                                                                     ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%PlatformInstallRoot%\Developer\Library\XCTest-development\usr ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D Foundation_DIR=S:\b\3\cmake\modules                                        ^
  -G Ninja                                                                      ^
  -S %SourceCache%\swift-corelibs-xctest || (exit /b)

cmake --build S:\b\4 || (exit /b)
cmake --build S:\b\4 --target install || (exit /b)

:: Info.plist
"%ProgramFiles(x86)%\Microsoft Visual Studio\Shared\Python39_64\python.exe" -c "import plistlib; print(str(plistlib.dumps({ 'DefaultProperties': { 'XCTEST_VERSION': 'development' } }), encoding='utf-8'))" > %PlatformInstallRoot%\Info.plist

:: tools-support-core
cmake                                                                           ^
  -B S:\b\5                                                                     ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe                                   ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -D CMAKE_MT=mt                                                                ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D Foundation_DIR=S:\b\3\cmake\modules                                        ^
  -D SQLite3_INCLUDE_DIR=S:\Library\sqlite-3.36.0\usr\include                   ^
  -D SQLite3_LIBRARY=S:\Library\sqlite-3.36.0\usr\lib\SQLite3.lib               ^
  -G Ninja                                                                      ^
  -S %SourceCache%\swift-tools-support-core || (exit /b)

cmake --build S:\b\5 || (exit /b)
cmake --build S:\b\5 --target install || (exit /b)

:: llbuild
cmake                                                                           ^
  -B S:\b\6                                                                     ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe                                 ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_CXX_FLAGS="-Xclang -fno-split-cold-code"                             ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -D CMAKE_MT=mt                                                                ^
  -D LLBUILD_SUPPORT_BINDINGS=Swift                                             ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D Foundation_DIR=S:\b\3\cmake\modules                                        ^
  -D SQLite3_INCLUDE_DIR=S:\Library\sqlite-3.36.0\usr\include                   ^
  -D SQLite3_LIBRARY=S:\Library\sqlite-3.36.0\usr\lib\SQLite3.lib               ^
  -G Ninja                                                                      ^
  -S %SourceCache%\llbuild || (exit /b)

cmake --build S:\b\6 || (exit /b)
cmake --build S:\b\6 --target install || (exit /b)

:: Yams
cmake                                                                           ^
  -B S:\b\7                                                                     ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D Foundation_DIR=S:\b\3\cmake\modules                                        ^
  -D XCTest_DIR=S:\b\4\cmake\modules                                            ^
  -G Ninja                                                                      ^
  -S %SourceCache%\Yams || (exit /b)

cmake --build S:\b\7 || (exit /b)
cmake --build S:\b\7 --target install || (exit /b)

:: swift-argument-parser
cmake                                                                           ^
  -B S:\b\8                                                                     ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D BUILD_TESTING=NO                                                           ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D Foundation_DIR=S:\b\3\cmake\modules                                        ^
  -D XCTest_DIR=S:\b\4\cmake\modules                                            ^
  -G Ninja                                                                      ^
  -S %SourceCache%\swift-argument-parser || (exit /b)

cmake --build S:\b\8 || (exit /b)
cmake --build S:\b\8 --target install || (exit /b)

:: swift-driver
cmake                                                                           ^
  -B S:\b\9                                                                     ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D Foundation_DIR=S:\b\3\cmake\modules                                        ^
  -D TSC_DIR=S:\b\5\cmake\modules                                               ^
  -D LLBuild_DIR=S:\b\6\cmake\modules                                           ^
  -D Yams_DIR=S:\b\7\cmake\modules                                              ^
  -D ArgumentParser_DIR=S:\b\8\cmake\modules                                    ^
  -G Ninja                                                                      ^
  -S %SourceCache%\swift-driver || (exit /b)

cmake --build S:\b\9 || (exit /b)
cmake --build S:\b\9 --target install || (exit /b)

:: swift-crypto
cmake                                                                           ^
  -B S:\b\10                                                                    ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D Foundation_DIR=S:\b\3\cmake\modules                                        ^
  -G Ninja                                                                      ^
  -S %SourceCache%\swift-crypto || (exit /b)
cmake --build S:\b\10 || (exit /b)
cmake --build S:\b\10 --target install || (exit /b)

:: swift-collections
cmake                                                                           ^
  -B S:\b\11                                                                    ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -G Ninja                                                                      ^
  -S %SourceCache%\swift-collections || (exit /b)
cmake --build S:\b\11 || (exit /b)
cmake --build S:\b\11 --target install || (exit /b)

:: swift-package-manager
cmake                                                                           ^
  -B S:\b\12                                                                    ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe                                   ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_Swift_FLAGS="-DCRYPTO_v2"                                            ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -D CMAKE_MT=mt                                                                ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D Foundation_DIR=S:\b\3\cmake\modules                                        ^
  -D TSC_DIR=S:\b\5\cmake\modules                                               ^
  -D LLBuild_DIR=S:\b\6\cmake\modules                                           ^
  -D ArgumentParser_DIR=S:\b\8\cmake\modules                                    ^
  -D SwiftDriver_DIR=S:\b\9\cmake\modules                                       ^
  -D SwiftCrypto_DIR=S:\b\10\cmake\modules                                      ^
  -D SwiftCollections_DIR=S:\b\11\cmake\modules                                 ^
  -G Ninja                                                                      ^
  -S %SourceCache%\swift-package-manager || (exit /b)

cmake --build S:\b\12 || (exit /b)
cmake --build S:\b\12 --target install || (exit /b)

:: indexstore-db
cmake                                                                           ^
  -B S:\b\13                                                                    ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_CXX_FLAGS="-Xclang -fno-split-cold-code"                             ^
  -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe                                   ^
  -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe                                 ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -D CMAKE_MT=mt                                                                ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D Foundation_DIR=S:\b\3\cmake\modules                                        ^
  -G Ninja                                                                      ^
  -S %SourceCache%\indexstore-db || (exit /b)

cmake --build S:\b\13 || (exit /b)
cmake --build S:\b\13 --target install || (exit /b)

:: sourcekit-lsp
cmake                                                                           ^
  -B S:\b\14                                                                    ^
  -D BUILD_SHARED_LIBS=YES                                                      ^
  -D CMAKE_BUILD_TYPE=Release                                                   ^
  -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe                                   ^
  -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe                                 ^
  -D CMAKE_INSTALL_PREFIX=%ToolchainInstallRoot%\usr                            ^
  -D CMAKE_MT=mt                                                                ^
  -D dispatch_DIR=S:\b\2\cmake\modules                                          ^
  -D Foundation_DIR=S:\b\3\cmake\modules                                        ^
  -D TSC_DIR=S:\b\5\cmake\modules                                               ^
  -D LLBuild_DIR=S:\b\6\cmake\modules                                           ^
  -D ArgumentParser_DIR=S:\b\8\cmake\modules                                    ^
  -D SwiftCollections_DIR=S:\b\11\cmake\modules                                 ^
  -D SwiftPM_DIR=S:\b\12\cmake\modules                                          ^
  -D IndexStoreDB_DIR=S:\b\13\cmake\modules                                     ^
  -G Ninja                                                                      ^
  -S %SourceCache%\sourcekit-lsp || (exit /b)

cmake --build S:\b\14 || (exit /b)
cmake --build S:\b\14 --target install || (exit /b)

