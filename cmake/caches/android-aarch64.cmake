
set(CMAKE_SYSTEM_NAME Android CACHE STRING "")
set(CMAKE_SYSTEM_VERSION 21 CACHE STRING "")

set(CMAKE_ANDROID_API 21 CACHE STRING "")
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a CACHE STRING "")

if(EXISTS C:/Microsoft/AndroidNDK64/android-ndk-r16b)
  set(CMAKE_ANDROID_NDK C:/Microsoft/AndroidNDK64/android-ndk-r16b CACHE FILEPATH "")
elseif(EXISTS C:/Microsoft/AndroidNDK64/android-ndk-r15c)
  set(CMAKE_ANDROID_NDK C:/Microsoft/AndroidNDK64/android-ndk-r15c CACHE FILEPATH "")
else()
  message(FATAL_ERROR "unable to find android NDK")
endif()

set(CMAKE_ANDROID_NDK_TOOLCHAIN_VERSION clang CACHE STRING "")
set(CMAKE_ANDROID_STL_TYPE c++_static CACHE STRING "")

