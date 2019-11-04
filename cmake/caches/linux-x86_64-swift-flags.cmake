
set(CMAKE_SWIFT_FLAGS
      -sdk ${CMAKE_Swift_SDK}
      -Xcc --sysroot=/
    CACHE STRING "")
set(CMAKE_SWIFT_LINK_FLAGS
      -sdk ${CMAKE_Swift_SDK}
      -Xclang-linker --sysroot=/
    CACHE STRING "")

set(CMAKE_Swift_FLAGS "-resource-dir ${CMAKE_Swift_SDK}/usr/lib/swift" CACHE STRING "")

