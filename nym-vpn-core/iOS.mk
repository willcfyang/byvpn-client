# This Makefile can only be used on macOS
OS := Darwin
include reproducible_builds.mk

# Minimum iOS deployment target used by clang
export IPHONEOS_DEPLOYMENT_TARGET = 16.0

RELEASE ?= true

RELEASE_FLAG :=
TARGET_DIR := debug

ifeq ($(RELEASE), true)
RELEASE_FLAG := --release
TARGET_DIR := release
endif

# Device + simulator (cargo-swift --platforms ios without --target builds both slices).
RUST_TRIPLET_DEVICE := aarch64-apple-ios
RUST_TRIPLET_SIM := aarch64-apple-ios-sim

LIB_CRATE_NAME := nym-vpn-lib-uniffi
LIB_CRATE_DIR := $(CURDIR)/crates/$(LIB_CRATE_NAME)
LIBWG_BUILD_DIR := $(CURDIR)/../build/lib/$(RUST_TRIPLET_DEVICE)
LIBWG_SIM_BUILD_DIR := $(CURDIR)/../build/lib/$(RUST_TRIPLET_SIM)

WIREGUARD_DIR := $(CURDIR)/../wireguard

# todo: consider migrating libwg builds to makefile to avoid rebuilds but for now this should make this makefile aware of changes to go sources
LIBWG_SOURCES := $(wildcard $(WIREGUARD_DIR)/libwg/*.go) $(wildcard $(WIREGUARD_DIR)/libwg/*/*.go)

.PHONY: build libwg swift-package clean

all: $(LIBWG_BUILD_DIR)/libwg.a $(LIBWG_SIM_BUILD_DIR)/libwg.a swift-package

build: $(LIBWG_BUILD_DIR)/libwg.a $(LIBWG_SIM_BUILD_DIR)/libwg.a
	$(ALL_IDEMPOTENT_FLAGS) cargo build --package $(LIB_CRATE_NAME) --target $(RUST_TRIPLET_DEVICE) $(RELEASE_FLAG)
	$(ALL_IDEMPOTENT_FLAGS) cargo build --package $(LIB_CRATE_NAME) --target $(RUST_TRIPLET_SIM) $(RELEASE_FLAG)

# Omit --target so cargo-swift emits device + ios-simulator slices in the xcframework.
swift-package: $(LIBWG_BUILD_DIR)/libwg.a $(LIBWG_SIM_BUILD_DIR)/libwg.a
	cd $(LIB_CRATE_DIR); \
	$(ALL_IDEMPOTENT_FLAGS) cargo swift package --accept-all --platforms ios --name NymVPNLib --xcframework-name NymVPNLibUniffi $(RELEASE_FLAG) ; \
	sed -i '' -e '/\.macOS(\.v10_15)/d' "NymVPNLib/Package.swift"

libwg: $(LIBWG_BUILD_DIR)/libwg.a $(LIBWG_SIM_BUILD_DIR)/libwg.a

$(LIBWG_BUILD_DIR)/libwg.a $(LIBWG_SIM_BUILD_DIR)/libwg.a: $(LIBWG_SOURCES)
	$(WIREGUARD_DIR)/build-wireguard-go.sh --ios

clean:
	rm -rf $(LIB_CRATE_DIR)/NymVPNLib
	rm -rf $(LIB_CRATE_DIR)/generated
	rm -rf $(LIBWG_BUILD_DIR) $(LIBWG_SIM_BUILD_DIR)
	cargo clean --target $(RUST_TRIPLET_DEVICE)
	cargo clean --target $(RUST_TRIPLET_SIM)
