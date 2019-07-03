
set(CMAKE_SWIFT_FLAGS
      -sdk ${CMAKE_Swift_SDK}
      -Xclang --sysroot=/
    CACHE STRING "")
set(CMAKE_SWIFT_LINK_FLAGS
      -sdk ${CMAKE_Swift_SDK}
      -Xclang-linker --sysroot=/
    CACHE STRING "")

