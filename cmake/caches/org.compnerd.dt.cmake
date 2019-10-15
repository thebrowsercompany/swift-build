
# --- global settings ---

set(LLVM_ENABLE_PROJECTS
      clang
      lld
    CACHE STRING "")

# --- LLVM ---

# NOTE(compnerd) enable assertions always, the toolchain will not provide enough
# context to resolve issues otherwise and may silently generate invalid output.
set(LLVM_ENABLE_ASSERTIONS YES CACHE BOOL "")

set(PACKAGE_VENDOR "compnerd.org" CACHE STRING "")
set(CLANG_VENDOR "compnerd.org" CACHE STRING "")
set(CLANG_VENDOR_UTI "org.compnerd.dt" CACHE STRING "")

# NOTE(compnerd) LLVM appends a VCS revision string to its package version,
# which we do not want.
set(LLVM_APPEND_VC_REV NO CACHE BOOL "")
set(LLVM_VERSION_SUFFIX "" CACHE STRING "")

# NOTE(compnerd) currently the x86 and ARM targets are the ones that we are
# building, so only enable the backends for those architectures.
set(LLVM_TARGETS_TO_BUILD AArch64 ARM X86 CACHE STRING "")

set(LLVM_INCLUDE_BENCHMARKS NO CACHE BOOL "")
set(LLVM_INCLUDE_DOCS NO CACHE BOOL "")
set(LLVM_INCLUDE_EXAMPLES NO CACHE BOOL "")

# NOTE(compnerd) we do not use the GO bindings and the test require additional
# dependency which can cause the tests to not always work properly.
set(LLVM_INCLUDE_GO_TESTS NO CACHE BOOL "")

# NOTE(compnerd) disable the gold plugin as we currently use lld.
set(LLVM_TOOL_GOLD_BUILD NO CACHE BOOL "")

# NOTE(compnerd we do not use the OCaml bindings
set(LLVM_ENABLE_OCAMLDOC NO CACHE BOOL "")

# set(LLVM_ENABLE_LIBXML2 NO CACHE BOOL "")
# set(LLVM_ENABLE_ZLIB NO CACHE BOOL "")

# NOTE(compnerd) enable relocation relaxation which can result in fewer
# relocations, enabling faster linking.
set(ENABLE_X86_RELAX_RELOCATIONS YES CACHE BOOL "")

# NOTE(compnerd) we like our Unix style names for the tools.
set(LLVM_INSTALL_BINUTILS_SYMLINKS YES CACHE BOOL "")

set(LLVM_BUILD_LLVM_DYLIB NO CACHE BOOL "")
set(LLVM_BUILD_LLVM_C_DYLIB NO CACHE BOOL "")

# NOTE(compnerd) generate PDBs when possible
# TODO(compnerd) enable PDBs again; this runs up against disk limitations
# set(LLVM_ENABLE_PDB YES CACHE BOOL "")

# NOTE(compnerd) install these tools and only the tools, not the static
# libraries to reduce the size of the toolchain and only distribute the
# supported items.
set(LLVM_INSTALL_TOOLCHAIN_ONLY YES CACHE BOOL "")
set(LLVM_TOOLCHAIN_TOOLS
      addr2line
      ar
      c++filt
      dsymutil
      dwp
      llvm-ar
      llvm-cov
      llvm-cvtres
      llvm-cxxfilt
      llvm-dlltool
      llvm-dwp
      llvm-ranlib
      llvm-lib
      llvm-mt
      llvm-nm
      llvm-objdump
      llvm-pdbutil
      llvm-profdata
      llvm-rc
      llvm-readelf
      llvm-readobj
      llvm-size
      llvm-strip
      llvm-symbolizer
      llvm-undname
      nm
      objcopy
      objdump
      ranlib
      readelf
      size
      strings
    CACHE STRING "")

set(CLANG_TOOLS
      clang
      clang-format
      clang-headers
      clang-tidy
    CACHE STRING "")

# --- lldb ---

# NOTE(compnerd) use the pre-generated swig bindings rather than building it
set(LLDB_ALLOW_STATIC_BINDINGS YES CACHE BOOL "")

# --- swift ---

set(SWIFT_VENDOR "compnerd.org" CACHE STRING "")

# NOTE(compnerd) don't bother building the documentation, this is not user
# facing documentation
set(SWIFT_INCLUDE_DOCS NO CACHE BOOL "")

# NOTE(compnerd) enable SourceKit, we want to provide this as part of the
# toolchain to enable semantic completion
set(SWIFT_BUILD_SOURCEKIT YES CACHE BOOL "")

# NOTE(compnerd) do not build the standard library (static or shared) nor the
# SDK overlay as part of the toolchain.  They will be provided as part of the
# SDK.
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
