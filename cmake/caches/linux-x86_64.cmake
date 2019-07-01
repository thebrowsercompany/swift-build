
set(CMAKE_C_COMPILER clang CACHE STRING "")
set(CMAKE_CXX_COMPILER clang++ CACHE STRING "")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-stack-protector -fomit-frame-pointer -fdata-sections -ffunction-sections" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "-Xlinker --gc-sections" CACHE STRING "" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS "-Xlinker --gc-sections" CACHE STRING "" FORCE)

if(EXISTS /usr/bin/sccache)
  set(CMAKE_C_COMPILER_LAUNCHER /usr/bin/sccache CACHE STRING "")
  set(CMAKE_CXX_COMPILER_LAUNCHER /usr/bin/sccache CACHE STRING "")
endif()
