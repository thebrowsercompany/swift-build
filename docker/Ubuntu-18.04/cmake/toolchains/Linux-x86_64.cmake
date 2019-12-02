set(CMAKE_C_COMPILER /Library/Developer/Toolchains/unknown-Asserts-development.xctoolchain/usr/bin/clang)
set(CMAKE_CXX_COMPILER /Library/Developer/Toolchains/unknown-Asserts-development.xctoolchain/usr/bin/clang++)
set(CMAKE_Swift_COMPILER /Library/Developer/Toolchains/unknown-Asserts-development.xctoolchain/usr/bin/swiftc)

set(CMAKE_C_COMPILER_TARGET x86_64-unknown-linux-gnu)
set(CMAKE_CXX_COMPILER_TARGET x86_64-unknown-linux-gnu)
set(CMAKE_Swift_COMPILER_TARGET x86_64-unknown-linux-gnu)

set(CMAKE_Swift_FLAGS "-resource-dir /Library/Developer/Platforms/Linux.platform/Developer/SDKs/Linux.sdk/usr/lib/swift -use-ld=lld")

list(APPEND CMAKE_C_STANDARD_INCLUDE_DIRECTORIES
  /Library/Developer/Platforms/Linux.platform/Developer/SDKs/Linux.sdk/usr/lib/swift
  /Library/Developer/Platforms/Linux.platform/Developer/SDKs/Linux.sdk/usr/lib/swift/Block)
list(APPEND CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES
  /Library/Developer/Platforms/Linux.platform/Developer/SDKs/Linux.sdk/usr/lib/swift
  /Library/Developer/Platforms/Linux.platform/Developer/SDKs/Linux.sdk/usr/lib/swift/Block)

set(CMAKE_EXE_LINKER_FLAGS -fuse-ld=lld)
set(CMAKE_SHARED_LINKER_FLAGS -fuse-ld=lld)
