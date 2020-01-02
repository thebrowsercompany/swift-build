
# NOTE(compnerd) default the compiler to `cl` but permit overriding it
set(CMAKE_C_COMPILER clang-cl CACHE STRING "")
set(CMAKE_C_COMPILER_TARGET thumbv7-unknown-windows-msvc CACHE STRING "")
set(CMAKE_CXX_COMPILER clang-cl CACHE STRING "")
set(CMAKE_CXX_COMPILER_TARGET thumbv7-unknown-windows-msvc CACHE STRING "")

set(CMAKE_C_FLAGS "--target=thumbv7-unknown-windows-msvc ${CMAKE_C_FLAGS} /GS- /Oy /Gw /Gy" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS "--target=thumbv7-unknown-windows-msvc ${CMAKE_CXX_FLAGS} /GS- /Oy /Gw /Gy" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "/INCREMENTAL:NO" CACHE STRING "" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS "/INCREMENTAL:NO" CACHE STRING "" FORCE)

# Set the CMAKE_SYSTEM_NAME, CMAKE_SYSTEM_PROCESSOR for the LLVM build to FORCE
# CMAKE_CROSSCOMPILING to TRUE
set(CMAKE_SYSTEM_NAME Windows CACHE STRING "" FORCE)
set(CMAKE_SYSTEM_PROCESSOR ARM CACHE STRING "" FORCE)

