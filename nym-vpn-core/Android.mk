# Makefile used for building `nym-vpn-lib` for Android

# cargo ndk always builds for Linux/Android
OS := Linux
include reproducible_builds.mk

RELEASE ?= true
DOCKER ?= false
ANDROID_NDK_HOME ?=
NDK_TOOLCHAIN_DIR ?=

RELEASE_FLAG :=
TARGET_DIR := debug
DOCKER_FLAG :=

ifeq ($(RELEASE), true)
RELEASE_FLAG := --release
TARGET_DIR := release
endif

ifeq ($(DOCKER), true)
DOCKER_FLAG := --docker
endif

ARCH_ARM64_V8 := arm64-v8a
ARCH_X86_64 := x86_64
STRIP_TOOL_BIN := llvm-strip
comma := ,

# Comma-separated ABIs; default both. Example: ANDROID_ABIS=arm64-v8a
ANDROID_ABIS ?= $(ARCH_ARM64_V8),$(ARCH_X86_64)
ABI_LIST := $(subst $(comma), ,$(ANDROID_ABIS))
NDK_TARGET_FLAGS := $(foreach abi,$(ABI_LIST),-t $(abi))

BUILD_ARM64 := $(filter $(ARCH_ARM64_V8),$(ABI_LIST))
BUILD_X86_64 := $(filter $(ARCH_X86_64),$(ABI_LIST))

ifneq ($(strip $(NDK_TOOLCHAIN_DIR)),)
# NDK_TOOLCHAIN_DIR may be a Windows-style path (e.g. C:\path\to\bin) when set
# by the Android Gradle plugin on Windows. Use Make's $(subst) to convert
# backslashes to forward slashes first (Make handles this reliably), then use
# sed to rewrite the drive-letter prefix (C:/ -> /C/) for MSYS2/Git Bash.
# On Linux/macOS neither transformation has any effect.
STRIP_TOOL := $(shell echo '$(subst \,/,$(NDK_TOOLCHAIN_DIR))' | sed 's|^\([A-Za-z]\):/|/\1/|')/$(STRIP_TOOL_BIN)
else
# Infer location of llvm-strip from cargo ndk using the same path conversion.
STRIP_TOOL := $(shell p=$$(cargo ndk-env --json -t $(ARCH_ARM64_V8) | jq -r .CLANG_PATH | sed 's|\\|/|g; s|^\([A-Za-z]\):/|/\1/|') ; dirname "$$p")/$(STRIP_TOOL_BIN)
endif

ANDROID_DIR := $(CURDIR)/../nym-vpn-android
UNIFFI_OUT_DIR := $(ANDROID_DIR)/core/src/main/java/net/nymtech/vpn
JNI_LIBS_DIR := $(ANDROID_DIR)/core/src/main/jniLibs
ARM64_V8_BUILD_DIR := $(JNI_LIBS_DIR)/$(ARCH_ARM64_V8)
X86_64_BUILD_DIR := $(JNI_LIBS_DIR)/$(ARCH_X86_64)

CARGO_TARGET_DIR ?= $(CURDIR)/target
DYNAMIC_LIB_PATH := $(CARGO_TARGET_DIR)/aarch64-linux-android/$(TARGET_DIR)/libnym_vpn_lib_uniffi.so
WIREGUARD_DIR := $(CURDIR)/../wireguard
LICENSES_FILE := $(ANDROID_DIR)/core/src/main/assets/licenses_rust.json

STRIP_TARGETS := libnym_vpn_lib.so libnym_vpn_lib_types.so

# todo: consider migrating libwg builds to makefile to avoid rebuilds but for now this should make this makefile aware of changes to go sources
LIBWG_SOURCES := $(wildcard $(WIREGUARD_DIR)/libwg/*.go) $(wildcard $(WIREGUARD_DIR)/libwg/*/*.go)

LIBWG_DEPS :=
ifneq ($(BUILD_ARM64),)
LIBWG_DEPS += $(ARM64_V8_BUILD_DIR)/libwg.so
endif
ifneq ($(BUILD_X86_64),)
LIBWG_DEPS += $(X86_64_BUILD_DIR)/libwg.so
endif

.PHONY: build clippy uniffi libwg strip clean

all: $(LIBWG_DEPS) build uniffi strip $(LICENSES_FILE)

build: $(LIBWG_DEPS)
	$(ALL_IDEMPOTENT_FLAGS) cargo ndk $(NDK_TARGET_FLAGS) -o $(JNI_LIBS_DIR) build --package nym-vpn-lib-uniffi --package nym-vpn-lib-types $(RELEASE_FLAG)
ifneq ($(BUILD_ARM64),)
	cd $(ARM64_V8_BUILD_DIR) ; \
	mv libnym_vpn_lib_uniffi.so libnym_vpn_lib.so
endif
ifneq ($(BUILD_X86_64),)
	cd $(X86_64_BUILD_DIR) ; \
	mv libnym_vpn_lib_uniffi.so libnym_vpn_lib.so
endif

clippy:
	$(ALL_IDEMPOTENT_FLAGS) cargo ndk $(NDK_TARGET_FLAGS) -o $(JNI_LIBS_DIR) clippy --package nym-vpn-lib-uniffi --package nym-vpn-lib-types $(RELEASE_FLAG)

strip: build
ifneq ($(BUILD_ARM64),)
	cd $(ARM64_V8_BUILD_DIR) ; \
	for target in $(STRIP_TARGETS); do \
		echo "Stripping $${target}" ; \
        $(STRIP_TOOL) --strip-unneeded --strip-debug --remove-section=.comment -o "stripped_$${target}" "$${target}" ; \
        mv stripped_$${target} $${target} ; \
    done
endif
ifneq ($(BUILD_X86_64),)
	cd $(X86_64_BUILD_DIR) ; \
	for target in $(STRIP_TARGETS); do \
		echo "Stripping $${target}" ; \
        $(STRIP_TOOL) --strip-unneeded --strip-debug --remove-section=.comment -o "stripped_$${target}" "$${target}" ; \
        mv stripped_$${target} $${target} ; \
    done
endif

uniffi: build
	cargo run --bin uniffi-bindgen generate \
		--library $(DYNAMIC_LIB_PATH) \
		--language kotlin --out-dir $(UNIFFI_OUT_DIR) -n

$(ARM64_V8_BUILD_DIR)/libwg.so: $(LIBWG_SOURCES)
	$(WIREGUARD_DIR)/build-wireguard-go.sh --android $(DOCKER_FLAG)

$(X86_64_BUILD_DIR)/libwg.so: $(ARM64_V8_BUILD_DIR)/libwg.so
	@# built as a side effect of the arm64 wireguard build above

libwg: $(LIBWG_DEPS)

clean:
	rm -rf $(ARM64_V8_BUILD_DIR) || true
	rm -rf $(X86_64_BUILD_DIR) || true
	rm -rf $(JNI_LIBS_DIR) || true

$(LICENSES_FILE): $(CURDIR)/Cargo.lock
	cargo license -j --avoid-dev-deps --current-dir $(CURDIR)/crates/nym-vpn-lib --filter-platform aarch64-linux-android --avoid-build-deps > $(LICENSES_FILE)
