set(CMAKE_Swift_COMPILER_TARGET x86_64-unknown-windows-msvc CACHE STRING "")
set(CMAKE_Swift_FLAGS "-resource-dir \"${CMAKE_Swift_SDK}/usr/lib/swift\" -L${CMAKE_Swift_SDK}/usr/lib/swift/windows" CACHE STRING "")
set(CMAKE_Swift_LINK_FLAGS "-resource-dir \"${CMAKE_Swift_SDK}/usr/lib/swift\" -L${CMAKE_Swift_SDK}/usr/lib/swift/windows" CACHE STRING "")

set(CMAKE_SWIFT_FLAGS "-resource-dir \"${CMAKE_Swift_SDK}/usr/lib/swift\"" CACHE STRING "")
set(CMAKE_SWIFT_LINK_FLAGS "-resource-dir \"${CMAKE_Swift_SDK}/usr/lib/swift\"" CACHE STRING "")

if(CMAKE_VERSION VERSION_LESS 3.16.0)
  set(CMAKE_Swift_LINK_LIBRARY_FLAG "-l" CACHE STRING "")
endif()
