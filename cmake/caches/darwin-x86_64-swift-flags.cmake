set(CMAKE_Swift_COMPILER_TARGET x86_64-apple-macosx10.13 CACHE STRING "")

set(SWIFT_STDLIB_DIR "${CMAKE_Swift_SDK}/usr" CACHE STRING "")

set(CMAKE_Swift_FLAGS "-resource-dir \"${SWIFT_STDLIB_DIR}/lib/swift\" -L${SWIFT_STDLIB_DIR}/lib/swift/macosx" CACHE STRING "")
set(CMAKE_Swift_LINK_FLAGS "-resource-dir \"${SWIFT_STDLIB_DIR}/lib/swift\" -L${SWIFT_STDLIB_DIR}/lib/swift/macosx" CACHE STRING "")

if(CMAKE_VERSION VERSION_LESS 3.16.0)
  set(CMAKE_Swift_LINK_LIBRARY_FLAG "-l" CACHE STRING "")
endif()
