PROJECT = tab-flow-macos.xcodeproj
DERIVED_DATA = DerivedData
APP_NAME = TabFlow
XCBEAUTIFY = scripts/xcbeautify

# Disable code signing if no certificate provided and not configured locally
SIGNING_FLAGS = $(shell if [ -z "$$APPLE_P12_CERTIFICATE" ] && ! grep -q "CODE_SIGN_IDENTITY" config/local.xcconfig 2>/dev/null; then echo "CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"; fi)

.PHONY: all build debug release test clean run profile help

all: debug

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build    Build Debug scheme (default)"
	@echo "  debug    Build Debug scheme"
	@echo "  release  Build Release scheme"
	@echo "  test     Run unit test suite"
	@echo "  run      Build and launch Debug app"
	@echo "  profile  Profile Debug app with Time Profiler"
	@echo "  clean    Remove build artifacts (DerivedData)"
	@echo "  help     Show this help message"

build: debug

debug:
	xcodebuild \
		-project $(PROJECT) \
		-scheme Debug \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		$(SIGNING_FLAGS)

release:
	set -o pipefail && xcodebuild \
		-project $(PROJECT) \
		-scheme Release \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		$(SIGNING_FLAGS) | $(XCBEAUTIFY)

test:
	set -o pipefail && xcodebuild test \
		-project $(PROJECT) \
		-scheme Test \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		$(SIGNING_FLAGS) | $(XCBEAUTIFY)

clean:
	rm -rf $(DERIVED_DATA)

run: debug
	open -n -a "$$(pwd)/$(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app" --args --logs=debug

profile: debug
	@profileFile="/tmp/profile_$$(date +%Y%m%d_%H%M%S)"; \
	xcrun xctrace record --instrument 'Time Profiler' --time-limit 20s --no-prompt --quiet --output "$$profileFile.trace" --launch -- $(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app --benchmark showUi 3; \
	xcrun xctrace export --input "$$profileFile.trace" --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' --output "$$profileFile.xml"; \
	echo "Exported profile to $$profileFile.xml"

