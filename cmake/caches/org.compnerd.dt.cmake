
# --- global settings ---

set(LLVM_ENABLE_PROJECTS
      clang
    CACHE STRING "")

# --- LLVM ---

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

