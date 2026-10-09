PROJECT = tab-flow-macos.xcodeproj
DERIVED_DATA = DerivedData
APP_NAME = TabFlow
XCBEAUTIFY = scripts/xcbeautify

# Disable code signing if no certificate provided and not configured locally
SIGNING_FLAGS = $(shell if [ -z "$$APPLE_P12_CERTIFICATE" ] && ! grep -q "CODE_SIGN_IDENTITY" config/local.xcconfig 2>/dev/null; then echo "CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"; fi)

.PHONY: all build debug release test clean run

all: debug

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
