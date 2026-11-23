# MenuTitle — build interface.
#
# `make` prints the list of targets. Every target is phony.

APP_NAME := MenuTitle
PRODUCT_NAME := MenuTitle
export MENUTITLE_SDK_VERSION := $(shell xcrun --sdk macosx --show-sdk-version)
CONFIGURATION ?= debug
# The version of a release comes from the command line: `make release VERSION=1.2.3`.
# A build without a version uses the placeholder below. The placeholder is not a
# release version, and a build that carries it must never be published.
LOCAL_VERSION := 0.0.0-local
VERSION ?= $(LOCAL_VERSION)
BUILD_NUMBER ?= 1
DIST_DIR := dist
APP_ARM := $(DIST_DIR)/$(APP_NAME)-arm64.app
APP_INTEL := $(DIST_DIR)/$(APP_NAME)-x86_64.app
BUNDLES ?= $(APP_ARM) $(APP_INTEL)
HOST_ARCH := $(shell uname -m)
HOST_TARGET := $(if $(filter arm64,$(HOST_ARCH)),app-arm,app-intel)
HOST_BUNDLE := $(if $(filter arm64,$(HOST_ARCH)),$(APP_ARM),$(APP_INTEL))
INSTALL_DIR ?= /Applications
INSTALL_APP := $(INSTALL_DIR)/$(APP_NAME).app
RELEASE_DIR := release
DMG_ARM := $(RELEASE_DIR)/$(APP_NAME)-$(VERSION)-arm64.dmg
DMG_INTEL := $(RELEASE_DIR)/$(APP_NAME)-$(VERSION)-x86_64.dmg
DMGS := $(DMG_ARM) $(DMG_INTEL)
DMG_NAMES := $(notdir $(DMGS))
CHECKSUMS := $(RELEASE_DIR)/checksums.txt
STAGING_DIR := $(RELEASE_DIR)/staging
CREATE_DMG ?= create-dmg
CREATE_DMG_FINALIZE_FLAGS ?= --skip-finalize
DMG_ICON := Resources/AppIcon.icns

ifneq ($(filter command line environment,$(origin VERSION)),)
RELEASE_VERSION := $(VERSION)
else
RELEASE_VERSION :=
endif

.PHONY: help build test verify app app-arm app-intel install run dmg dmg-arm \
	dmg-intel release-artifacts release-notes release clean clean-release

.DEFAULT_GOAL := help

## help — list every target

help:
	@printf '%s\n' \
		'MenuTitle — build targets.' \
		'' \
		'  help                  List every target (default).' \
		'  build                 Build the Swift package in the development configuration.' \
		'  test                  Run the changelog check and the SwiftPM test suite.' \
		'  verify                Check each bundle: architecture, SDK, version and signature.' \
		'  app                   Build both app bundles: dist/MenuTitle-arm64.app and dist/MenuTitle-x86_64.app.' \
		'  app-arm               Build the arm64 app bundle.' \
		'  app-intel             Build the x86_64 app bundle.' \
		'  dmg                   Build both disk images.' \
		'  dmg-arm               Build release/MenuTitle-<version>-arm64.dmg.' \
		'  dmg-intel             Build release/MenuTitle-<version>-x86_64.dmg.' \
		'  release-artifacts     Build both disk images and release/checksums.txt, then verify it.' \
		'  release-notes VERSION=x.y.z  Print the changelog section of a version.' \
		'  release VERSION=x.y.z  Bump the changelog, test, build, verify, commit and tag.' \
		'  install               Copy the app bundle of this Mac into /Applications.' \
		'  run                   Install the app bundle of this Mac and launch it.' \
		'  clean                 Remove .build/, dist/ and release/.' \
		'' \
		'Notes' \
		'  The version of a release comes from the command line: make release VERSION=1.2.3.' \
		'  A build without a version uses 0.0.0-local. That version is a placeholder for a' \
		'  local dry run, and a build that carries it must never be published.' \
		'  The release publishes MenuTitle-<version>-arm64.dmg, MenuTitle-<version>-x86_64.dmg' \
		'  and checksums.txt. The names must not change, because the Homebrew tap matches' \
		'  the assets by name.' \
		'  `make verify` checks both bundles. Set BUNDLES to check other bundles.' \
		'  CHANGELOG.md follows the shared shape. `make test` checks it.' \
		'  `make release` refuses a dirty working tree and a version whose tag already exists.' \
		'  It never pushes. Signing stays ad-hoc: identity "-", no notarization.' \
		'  create-dmg is needed for the dmg target: brew install create-dmg.'

## build — build the package in the development configuration

build:
	swift build -c $(CONFIGURATION)

## test — the test suite

test:
	./scripts/changelog.sh check
	swift test

## verify — check the built bundles

verify:
	@if [ -z "$(strip $(BUNDLES))" ]; then \
		echo "error: BUNDLES is empty, so there is nothing to verify."; \
		exit 1; \
	fi; \
	for bundle in $(BUNDLES); do \
		test -d "$$bundle" || { \
			echo "error: $$bundle is missing. Run make app first."; \
			exit 1; \
		}; \
		case "$$bundle" in \
		*-arm64.app) want=arm64 ;; \
		*-x86_64.app) want=x86_64 ;; \
		*) echo "error: $$bundle names no architecture; use ...-arm64.app or ...-x86_64.app."; exit 1 ;; \
		esac; \
		binary="$$bundle/Contents/MacOS/$(PRODUCT_NAME)"; \
		archs="$$(lipo -archs "$$binary")"; \
		echo "$$bundle: architectures $$archs"; \
		test "$$archs" = "$$want" || { \
			echo "error: $$bundle expected $$want, got $$archs."; \
			exit 1; \
		}; \
		sdk="$$(vtool -show-build "$$binary" | awk '$$1 == "sdk" { print $$2; exit }')"; \
		echo "$$bundle: recorded SDK $${sdk:-none}"; \
		if [ -z "$$sdk" ]; then \
			echo "error: $$bundle records no SDK version."; \
			exit 1; \
		fi; \
		awk -v sdk="$$sdk" 'BEGIN { exit !(sdk + 0 >= 26.0) }' || { \
			echo "error: $$bundle records SDK $$sdk; Liquid Glass needs 26.0 or newer."; \
			exit 1; \
		}; \
		version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$$bundle/Contents/Info.plist")"; \
		echo "$$bundle: version $$version (expected $(VERSION))"; \
		test "$$version" = "$(VERSION)" || { \
			echo "error: $$bundle reports $$version, but $(VERSION) was expected."; \
			exit 1; \
		}; \
		codesign --verify --deep --strict "$$bundle" || exit 1; \
	done; \
	echo "Verified $(BUNDLES)."

# $(1) is the bundle, $(2) the architecture. Each architecture builds into its
# own scratch path, because SwiftPM otherwise writes both into .build/out and
# the second build overwrites the binary of the first.
define build_bundle
	swift build -c $(CONFIGURATION) --arch $(2) --scratch-path .build/$(2)
	rm -rf "$(1)"
	mkdir -p "$(1)/Contents/MacOS" "$(1)/Contents/Resources"
	cp "$$(swift build -c $(CONFIGURATION) --arch $(2) --scratch-path .build/$(2) --show-bin-path)/$(PRODUCT_NAME)" "$(1)/Contents/MacOS/$(PRODUCT_NAME)"
	cp Info.plist "$(1)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(1)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$(1)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(1)/Contents/Resources/AppIcon.icns"
	printf 'APPL????' > "$(1)/Contents/PkgInfo"
	codesign --force --sign - "$(1)"
endef

## app — the bundles the product ships

app: app-arm app-intel

## app-arm — the arm64 bundle

app-arm:
	$(call build_bundle,$(APP_ARM),arm64)

## app-intel — the x86_64 bundle

app-intel:
	$(call build_bundle,$(APP_INTEL),x86_64)

## install — copy the bundle of this Mac into the applications folder

install: $(HOST_TARGET)
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_APP)"
	cp -R "$(HOST_BUNDLE)" "$(INSTALL_APP)"

## run — install the bundle of this Mac and launch it

run: install
	open "$(INSTALL_APP)"

# $(1) is the bundle, $(2) the disk image, $(3) the staging folder.
define build_dmg
	rm -rf "$(3)"
	mkdir -p "$(3)"
	cp -R "$(1)" "$(3)/$(APP_NAME).app"
	$(CREATE_DMG) --volname "$(APP_NAME)" --volicon "$(DMG_ICON)" --window-size 660 440 --icon "$(APP_NAME).app" 170 250 --app-drop-link 490 250 --hide-extension "$(APP_NAME).app" --no-internet-enable $(CREATE_DMG_FINALIZE_FLAGS) "$(2)" "$(3)"
	if [ -n "$(CREATE_DMG_FINALIZE_FLAGS)" ]; then hdiutil convert "$(2)" -format UDZO -o "$(2).final"; mv "$(2).final.dmg" "$(2)"; fi
endef

## clean-release — empty the release directory

clean-release:
	rm -rf "$(RELEASE_DIR)"

## dmg — both disk images

dmg: dmg-arm dmg-intel

## dmg-arm — the arm64 disk image

dmg-arm: CONFIGURATION := release
dmg-arm: clean-release app-arm
	$(call build_dmg,$(APP_ARM),$(DMG_ARM),$(STAGING_DIR)/arm64)

## dmg-intel — the x86_64 disk image

dmg-intel: CONFIGURATION := release
dmg-intel: clean-release app-intel
	$(call build_dmg,$(APP_INTEL),$(DMG_INTEL),$(STAGING_DIR)/intel)

## release-artifacts — the disk images and the checksum file the tap expects

release-artifacts: dmg
	cd "$(RELEASE_DIR)" && shasum -a 256 $(DMG_NAMES) > checksums.txt
	@cd "$(RELEASE_DIR)" && shasum -a 256 -c checksums.txt
	@echo "Wrote $(DMGS) and $(CHECKSUMS)."

## release-notes — print the changelog section of a version

release-notes:
	@if [ -z "$(strip $(RELEASE_VERSION))" ]; then \
		echo "error: make release-notes needs a version, for example: make release-notes VERSION=1.2.3"; \
		exit 1; \
	fi
	@./scripts/changelog.sh notes "$(RELEASE_VERSION)"

## release — bump, test, build, verify, commit and tag, without pushing

release:
	@if [ -z "$(strip $(RELEASE_VERSION))" ]; then \
		echo "error: make release needs a version on the command line, for example:"; \
		echo "       make release VERSION=1.2.3"; \
		exit 1; \
	fi
	@APP_NAME="$(APP_NAME)" ./scripts/release.sh "$(RELEASE_VERSION)"

## clean — remove everything the build produces

clean:
	rm -rf .build "$(DIST_DIR)" "$(RELEASE_DIR)"
	@echo "Removed .build/, $(DIST_DIR)/ and $(RELEASE_DIR)/."
