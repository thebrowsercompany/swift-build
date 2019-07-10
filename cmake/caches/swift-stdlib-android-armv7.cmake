
set(SWIFT_HOST_VARIANT_SDK ANDROID CACHE STRING "")
set(SWIFT_HOST_VARIANT_ARCH armv7 CACHE STRING "")

# build just the standard library
set(SWIFT_INCLUDE_TOOLS NO CACHE BOOL "")
set(SWIFT_INCLUDE_TESTS NO CACHE BOOL "")
set(SWIFT_INCLUDE_DOCS NO CACHE BOOL "")

# build with the host compiler
set(SWIFT_BUILD_RUNTIME_WITH_HOST_COMPILER YES CACHE BOOL "")

# android configuration
set(SWIFT_ANDROID_API_LEVEL 21 CACHE STRING "")
if($ENV{SWIFT_ANDROID_NDK_PATH})
  set(SWIFT_ANDROID_NDK_PATH $ENV{SWIFT_ANDROID_NDK_PATH} CACHE STRING "")
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Windows)
  if(EXISTS C:/Microsoft/AndroidNDK64/android-ndk-r16b)
    set(SWIFT_ANDROID_NDK_PATH "C:/Microsoft/AndroidNDK64/android-ndk-r16b" CACHE STRING "")
  else()
    message(FATAL_ERROR "unable to find android NDK")
  endif()
else()
  message(FATAL_ERROR "unable to find android NDK")
endif()
set(SWIFT_ANDROID_NDK_GCC_VERSION 4.9 CACHE STRING "")

# TODO(compnerd) we should fix the lld.exe spelling
set(SWIFT_ENABLE_LLD_LINKER FALSE CACHE BOOL "")
set(SWIFT_ENABLE_GOLD_LINKER TRUE CACHE BOOL "")
