need := 3.82
ifneq ($(need), $(firstword $(sort $(MAKE_VERSION) $(need))))
  $(error You need at least make version >= $(need))
endif

BuildOS := $(shell uname -s)
BuildArch := $(shell uname -m)
ifeq ($(BuildArch),amd64)
  BuildArch := x86_64
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

CMake := $(shell which cmake)
Ninja := $(shell which ninja)

CMakeFlags := -G Ninja                                                         \
              -DCMAKE_MAKE_PROGRAM=$(Ninja)                                    \
              -DCMAKE_BUILD_TYPE=$(CMakeBuildType)                             \
              -DCMAKE_INSTALL_PREFIX= # DESTDIR will set the actual path

# inform the build where the source tree resides
CMakeFlags += -DTOOLCHAIN_SOURCE_DIR=$(SourceDir)

ifeq ($(BOOTSTRAP),)
  CMakeFlags += -DCMAKE_TOOLCHAIN_FILE=$(CMakeToolchains)/Toolchain-bootstrap.cmake
ifneq ($(MAKECMDGOALS),bootstrap-target-swift)
  CMakeFlags += -DCMAKE_SYSTEM_NAME=$(HostOS) -DCMAKE_SYSTEM_PROCESSOR=$(HostArch)
endif
else
  CMakeFlags += -DCMAKE_TOOLCHAIN_FILE=$(CMakeToolchains)/Toolchain-$(Host).cmake
  CMakeFlags += -DCMAKE_SYSTEM_NAME=$(HostOS) -DCMAKE_SYSTEM_PROCESSOR=$(HostArch)
endif

Vendor := unknown
Version := Default

XCToolchain = $(Vendor)-$(AssertsVariant)-$(Version).xctoolchain
BootstrapXCToolchain = unknown-Asserts-bootstrap.xctoolchain
SwiftStandardLibraryTarget := swift-stdlib-$(shell echo $(HostOS) | tr '[A-Z]' '[a-z]')

DESTDIR := $(or $(DESTDIR),$(SourceDir)/prebuilt/$(Host)/Developer/Toolchains/$(XCToolchain)/usr)

# --- bootstrap ---
.PHONY: bootstrap-toolchain
bootstrap-toolchain: BootstrapToolchain := $(SourceDir)/build/Release/$(Build)/Developer/Toolchains/$(BootstrapXCToolchain)
bootstrap-toolchain:
	$(MAKE) BOOTSTRAP=1 DESTDIR=$(BootstrapToolchain)/usr BuildType=Release Host=$(Build) toolchain

.PHONY: bootstrap-target-swift
bootstrap-target-swift: bootstrap-toolchain
bootstrap-target-swift: BootstrapToolchain := $(SourceDir)/build/Release/$(Build)/Developer/Toolchains/$(BootstrapXCToolchain)
bootstrap-target-swift:
	$(MAKE) DESTDIR=$(BootstrapToolchain)/usr BuildType=$(BuildType) $(SwiftStandardLibraryTarget)

# --- toolchain ---
.PHONY: toolchain
toolchain: $(BuildDir)/toolchain/build.ninja
toolchain:
	DESTDIR=$(DESTDIR) $(Ninja) -C $(BuildDir)/toolchain install-distribution$(InstallVariant)

.ONESHELL: $(BuildDir)/toolchain/build.ninja
ifeq ($(BOOTSTRAP),)
$(BuildDir)/toolchain/build.ninja: bootstrap-toolchain
endif
$(BuildDir)/toolchain/build.ninja:
	mkdir -p $(BuildDir)/toolchain
	cd $(BuildDir)/toolchain
	$(CMake) $(CMakeFlags)                                                 \
	  -DLLVM_ENABLE_ASSERTIONS=$(AssertsEnabled)                           \
	  -DSWIFT_PATH_TO_LIBDISPATCH_SOURCE=$(SourceDir)/swift-corelibs-libdispatch \
	  -C $(CMakeCaches)/toolchain-common.cmake                             \
	  -C $(CMakeCaches)/toolchain.cmake                                    \
	  -C $(CMakeCaches)/toolchain-$(Host).cmake                            \
	$(SourceDir)/llvm

# --- swift-stdlib ---
define build-swift-stdlib
# swift-stdlib-$(1): bootstrap-toolchain
swift-stdlib-$(1): $$(SourceDir)/build/$$(BuildType)/swift-stdlib-$(1)/build.ninja
swift-stdlib-$(1):
	DESTDIR=$(DESTDIR) $(Ninja) -C $$(SourceDir)/build/$$(BuildType)/swift-stdlib-$(1) install

.ONESHELL: $$(SourceDir)/build/$$(BuildType)/swift-stdlib-$(1)/build.ninja
$$(SourceDir)/build/$$(BuildType)/swift-stdlib-$(1)/build.ninja:
	mkdir -p $$(SourceDir)/build/$$(BuildType)/swift-stdlib-$(1)
	cd $$(SourceDir)/build/$$(BuildType)/swift-stdlib-$(1)
	$$(CMake) $$(CMakeFlags)                                               \
	  -C $$(CMakeCaches)/swift-stdlib-common.cmake                         \
	  -C $$(CMakeCaches)/swift-stdlib-$(1).cmake                           \
	$$(SourceDir)/swift
endef

swift-stdlib-targets := linux windows android
$(foreach target,$(swift-stdlib-targets),$(eval $(call build-swift-stdlib,$(target))))

# --- libdispatch ---
.PHONY: swift-corelibs-libdispatch
swift-corelibs-libdispatch: $(BuildDir)/swift-corelibs-libdispatch/build.ninja
	DESTDIR=$(DESTDIR) $(Ninja) -C $(BuildDir)/swift-corelibs-libdispatch install

.ONESHELL: $(BuildDir)/swift-corelibs-libdispatch/build.ninja
$(BuildDir)/swift-corelibs-libdispatch/build.ninja: bootstrap-toolchain bootstrap-target-swift
$(BuildDir)/swift-corelibs-libdispatch/build.ninja:
	mkdir -p $(BuildDir)/swift-corelibs-libdispatch
	cd $(BuildDir)/swift-corelibs-libdispatch
	$(CMake) $(CMakeFlags)                                                 \
	  -C $(CMakeCaches)/swift-corelibs-libdispatch-$(Host).cmake           \
	  -DSwift_DIR=$(SourceDir)/build/$(BuildType)/$(SwiftStandardLibraryTarget)/lib/cmake/swift \
	$(SourceDir)/swift-corelibs-libdispatch

# --- foundation ---
.PHONY: swift-corelibs-foundation
swift-corelibs-foundation: bootstrap-target-swift
swift-corelibs-foundation: $(BuildDir)/swift-corelibs-foundation/build.ninja
swift-corelibs-foundation:
	DESTDIR=$(DESTDIR) $(Ninja) -C $(BuildDir)/swift-corelibs-foundation install

.ONESHELL: $(BuildDir)/swift-corelibs-foundation/build.ninja
$(BuildDir)/swift-corelibs-foundation/build.ninja: bootstrap-toolchain
$(BuildDir)/swift-corelibs-foundation/build.ninja: swift-corelibs-libdispatch
$(BuildDir)/swift-corelibs-foundation/build.ninja:
	mkdir -p $(BuildDir)/swift-corelibs-foundation
	cd $(BuildDir)/swift-corelibs-foundation
	$(CMake) $(CMakeFlags)                                                 \
	  -C $(CMakeCaches)/swift-corelibs-foundation-$(Host).cmake            \
	-DFOUNDATION_PATH_TO_LIBDISPATCH_SOURCE=$(SourceDir)/swift-corelibs-libdispatch \
	-DFOUNDATION_PATH_TO_LIBDISPATCH_BUILD=$(BuildDir)/swift-corelibs-libdispatch \
	$(SourceDir)/swift-corelibs-foundation

# --- default ---
.DEFAULT_GOAL := default
default:

# --- distclean ---
distclean:
	rm -rf $(BuildDir)

