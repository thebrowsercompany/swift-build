
ifeq ($(OS),Windows_NT)
  BuildOS := Windows
  ifeq ($(PROCESSOR_ARCHITEW6432),AMD64)
    BuildArch := x86_64
  else ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
    BuildArch := x86_64
  else ifeq ($(PROCESSOR_ARCHITECTURE),X86)
    BuildArch := i686
  else
    $(error "Unknown processor: $(PROCESSOR_ARCHITECTURE)")
  endif
else
  BuildOS := $(shell uname -s)
  BuildArch := $(shell uname -m)
  ifeq ($(BuildArch),amd64)
    BuildArch := x86_64
  endif
endif

Build := $(BuildOS)-$(BuildArch)

#  BuildType | CMake Build Type | Debug | Strip | Asserts
# -----------+------------------+-------+-------+---------
# Debug      | Debug            | -g    | N     | Y
# Release    | RelWithDebInfo   | -g    | Y     | Y

BuildType := Debug

Host := $(Build)
HostOS := $(firstword $(subst -, ,$(Host)))
HostArch := $(lastword $(subst -, ,$(Host)))

ifeq ($(BuildType),Debug)
  CMakeBuildType := Debug
  AssertsEnabled := YES
  AssertsVariant := Asserts
  InstallVariant :=
else ifeq ($(BuildType),Release)
  CMakeBuildType := RelWithDebInfo
  AssertsEnabled := YES
  AssertsVariant := Asserts
  InstallVariant := -stripped
else
  $(error BuildType should be either Debug or Release)
endif

SourceDir := $(abspath $(dir $(realpath $(lastword $(MAKEFILE_LIST))))/..)
BuildDir := $(SourceDir)/build/$(BuildType)/$(Host)

CMakeCaches := $(SourceDir)/infrastructure/cmake/caches
CMakeScripts := $(SourceDir)/infrastructure/cmake/scripts
CMakeToolchains := $(SourceDir)/infrastructure/cmake/toolchains

ifeq ($(OS),Windows_NT)
  CMake := $(shell where cmake)
  Ninja := $(shell where ninja)
else
  CMake := $(shell which cmake)
  Ninja := $(shell which ninja)
endif

CMakeFlags := -G Ninja                                                         \
              -DCMAKE_MAKE_PROGRAM="$(Ninja)"                                  \
              -DCMAKE_BUILD_TYPE=$(CMakeBuildType)                             \
              -DCMAKE_INSTALL_PREFIX= # DESTDIR will set the actual path

# inform the build where the source tree resides
CMakeFlags += -DTOOLCHAIN_SOURCE_DIR=$(SourceDir)

CMakeFlags += -DCMAKE_TOOLCHAIN_FILE=$(CMakeToolchains)/Toolchain-$(Host).cmake
CMakeFlags += -DCMAKE_SYSTEM_NAME=$(HostOS) -DCMAKE_SYSTEM_PROCESSOR=$(HostArch)

Vendor := unknown
Version := Default

XCToolchain = $(Vendor)-$(AssertsVariant)-$(Version).xctoolchain
SwiftStandardLibraryTarget := swift-stdlib-$(shell echo $(HostOS) | tr '[A-Z]' '[a-z]')

DESTDIR := $(or $(DESTDIR),$(SourceDir)/prebuilt/$(Host)/Developer/Toolchains/$(XCToolchain)/usr)

# --- toolchain-tools ---
$(SourceDir)/build/Release/$(Build)/toolchain-tools/build.ninja:
	"$(CMake)"                                                             \
	  -B $(SourceDir)/build/Release/$(Build)/toolchain-tools               \
	  -D CMAKE_BUILD_TYPE=Release                                          \
	  -D CMAKE_MAKE_PROGRAM="$(Ninja)"                                     \
	  -D LLVM_DISABLE_PYTHON=YES                                           \
	  -D LLVM_ENABLE_ASSERTIONS=NO                                         \
	  -D LLVM_ENABLE_PROJECTS="clang;lldb"                                 \
	  -G Ninja                                                             \
	  -S $(SourceDir)/llvm-project/llvm

$(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/clang-tblgen: $(SourceDir)/build/Release/$(Build)/toolchain-tools/build.ninja
$(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/clang-tblgen:
	"$(Ninja)" -C $(SourceDir)/build/Release/$(Build)/toolchain-tools clang-tblgen

$(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/lldb-tblgen: $(SourceDir)/build/Release/$(Build)/toolchain-tools/build.ninja
$(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/lldb-tblgen:
	"$(Ninja)" -C $(SourceDir)/build/Release/$(Build)/toolchain-tools lldb-tblgen

$(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/llvm-tblgen: $(SourceDir)/build/Release/$(Build)/toolchain-tools/build.ninja
$(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/llvm-tblgen:
	"$(Ninja)" -C $(SourceDir)/build/Release/$(Build)/toolchain-tools llvm-tblgen

# --- toolchain ---
$(BuildDir)/toolchain/build.ninja: $(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/clang-tblgen
$(BuildDir)/toolchain/build.ninja: $(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/lldb-tblgen
$(BuildDir)/toolchain/build.ninja: $(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/llvm-tblgen
$(BuildDir)/toolchain/build.ninja:
	"$(CMake)" $(CMakeFlags)                                               \
	  -B $(BuildDir)/toolchain                                             \
	  -D LLVM_ENABLE_ASSERTIONS=$(AssertsEnabled)                          \
	  -D LLVM_USE_HOST_TOOLS=NO                                            \
	  -D CLANG_TABLEGEN=$(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/clang-tblgen \
	  -D LLDB_TABLEGEN=$(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/lldb-tblgen \
	  -D LLVM_TABLEGEN=$(SourceDir)/build/Release/$(Build)/toolchain-tools/bin/llvm-tblgen \
	  -D SWIFT_PATH_TO_LIBDISPATCH_SOURCE=$(SourceDir)/swift-corelibs-libdispatch \
	  -C $(CMakeCaches)/toolchain-common.cmake                             \
	  -C $(CMakeCaches)/toolchain.cmake                                    \
	  -C $(CMakeCaches)/toolchain-$(Host).cmake                            \
	  -S $(SourceDir)/llvm

.PHONY: toolchain
toolchain: $(BuildDir)/toolchain/build.ninja
toolchain:
	"$(CMake)" -E env DESTDIR=$(DESTDIR) "$(Ninja)" -C $(BuildDir)/toolchain install-distribution$(InstallVariant)

# --- swift-stdlib ---
define build-swift-stdlib
swift-stdlib-$(1): $$(SourceDir)/build/$$(BuildType)/swift-stdlib-$(1)/build.ninja
swift-stdlib-$(1):
	"$(CMake)" -E env DESTDIR=$(DESTDIR) "$(Ninja)" -C $$(SourceDir)/build/$$(BuildType)/swift-stdlib-$(1) install

$$(SourceDir)/build/$$(BuildType)/swift-stdlib-$(1)/build.ninja:
	"$$(CMake)" $$(CMakeFlags)                                             \
	  -B $$(SourceDir)/build/$$(BuildType)/swift-stdlib-$(1)               \
	  -C $$(CMakeCaches)/swift-stdlib-common.cmake                         \
	  -C $$(CMakeCaches)/swift-stdlib-$(1).cmake                           \
	  -S $$(SourceDir)/swift
endef

swift-stdlib-targets := linux windows android
$(foreach target,$(swift-stdlib-targets),$(eval $(call build-swift-stdlib,$(target))))

# --- libdispatch ---
.PHONY: swift-corelibs-libdispatch
swift-corelibs-libdispatch: $(BuildDir)/swift-corelibs-libdispatch/build.ninja
	"$(CMake)" -E env DESTDIR=$(DESTDIR) "$(Ninja)" -C $(BuildDir)/swift-corelibs-libdispatch install

$(BuildDir)/swift-corelibs-libdispatch/build.ninja: bootstrap-target-swift
$(BuildDir)/swift-corelibs-libdispatch/build.ninja:
	"$(CMake)" $(CMakeFlags)                                               \
	  -B $(BuildDir)/swift-corelibs-libdispatch                            \
	  -C $(CMakeCaches)/swift-corelibs-libdispatch-$(Host).cmake           \
	  -D Swift_DIR=$(SourceDir)/build/$(BuildType)/$(SwiftStandardLibraryTarget)/lib/cmake/swift \
	  -S $(SourceDir)/swift-corelibs-libdispatch

# --- foundation ---
.PHONY: swift-corelibs-foundation
swift-corelibs-foundation: bootstrap-target-swift
swift-corelibs-foundation: $(BuildDir)/swift-corelibs-foundation/build.ninja
swift-corelibs-foundation:
	"$(CMake)" -E env DESTDIR=$(DESTDIR) "$(Ninja)" -C $(BuildDir)/swift-corelibs-foundation install

$(BuildDir)/swift-corelibs-foundation/build.ninja: swift-corelibs-libdispatch
$(BuildDir)/swift-corelibs-foundation/build.ninja:
	"$(CMake)" $(CMakeFlags)                                               \
	  -B $(BuildDir)/swift-corelibs-foundation                             \
	  -C $(CMakeCaches)/swift-corelibs-foundation-$(Host).cmake            \
	  -D FOUNDATION_PATH_TO_LIBDISPATCH_SOURCE=$(SourceDir)/swift-corelibs-libdispatch \
	  -D FOUNDATION_PATH_TO_LIBDISPATCH_BUILD=$(BuildDir)/swift-corelibs-libdispatch \
	  -S $(SourceDir)/swift-corelibs-foundation

# --- default ---
.DEFAULT_GOAL := default
default:

# --- distclean ---
distclean:
	rm -rf $(BuildDir)

