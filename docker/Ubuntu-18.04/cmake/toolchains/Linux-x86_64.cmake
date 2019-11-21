set(CMAKE_C_COMPILER_TARGET x86_64-unknown-linux-gnu)
set(CMAKE_CXX_COMPILER_TARGET x86_64-unknown-linux-gnu)
set(CMAKE_Swift_COMPILER_TARGET x86_64-unknown-linux-gnu)

set(CMAKE_Swift_FLAGS "-resource-dir /Library/Developer/Platforms/Linux.platform/Developer/SDKs/Linux.sdk/usr/lib/swift")

set(CMAKE_EXE_LINKER_FLAGS -fuse-ld=lld)
set(CMAKE_SHARED_LINKER_FLAGS -fuse-ld=lld)
