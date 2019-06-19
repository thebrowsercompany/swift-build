
set(CMAKE_SWIFT_FLAGS
-resource-dir ${SWIFT_ANDROID_SDK}/usr/lib/swift
-Xcc --sysroot=${CMAKE_ANDROID_NDK}/sysroot
CACHE STRING "")
set(CMAKE_SWIFT_LINK_FLAGS
-resource-dir ${SWIFT_ANDROID_SDK}/usr/lib/swift
-tools-directory ${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/windows-x86_64/bin
-Xclang-linker --gcc-toolchain=${CMAKE_ANDROID_NDK}/toolchains/arm-linux-android-4.9/prebuilt/windows-x86_64
-Xclang-linker --sysroot=${CMAKE_ANDROID_NDK}/platforms/android-${CMAKE_ANDROID_API}/arch-arm
-Xclang-linker -fuse-ld=gold.exe
CACHE STRING "")

