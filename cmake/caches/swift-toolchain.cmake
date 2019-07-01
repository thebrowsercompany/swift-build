
set(SWIFT_INCLUDE_DOCS NO CACHE BOOL "")

set(SWIFT_BUILD_SOURCEKIT YES CACHE BOOL "")

set(SWIFT_BUILD_STATIC_STDLIB NO CACHE BOOL "")
set(SWIFT_BUILD_STATIC_SDK_OVERLAY NO CACHE BOOL "")

set(SWIFT_BUILD_DYNAMIC_STDLIB NO CACHE BOOL "")
set(SWIFT_BUILD_DYNAMIC_SDK_OVERLAY NO CACHE BOOL "")

set(SWIFT_INSTALL_COMPONENTS
      autolink-driver
      compiler
      clang-builtin-headers
      editor-integration
      tools
      sourcekit-inproc
      swift-remote-mirror
      swift-remote-mirror-headers
    CACHE STRING "")