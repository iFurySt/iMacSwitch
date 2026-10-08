CONFIGURATION ?= Debug
DERIVED_DATA ?= $(CURDIR)/.build/DerivedData
APP_PATH ?= $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/iMacSwitch.app
OUTPUT_DIR ?= $(CURDIR)/dist

.PHONY: build check ci package clean new-history new-plan

build:
	CONFIGURATION="$(CONFIGURATION)" DERIVED_DATA="$(DERIVED_DATA)" ./scripts/build.sh

check:
	./scripts/check-project.sh

ci: check
	CONFIGURATION=Release DERIVED_DATA="$(DERIVED_DATA)" CODE_SIGNING_ALLOWED=NO ./scripts/build.sh

package:
	./scripts/package.sh "$(APP_PATH)" "$(OUTPUT_DIR)"

clean:
	xcodebuild -project iMacSwitch.xcodeproj -scheme iMacSwitch clean

new-history:
	@if [ -z "$(SLUG)" ]; then echo "用法: make new-history SLUG=变更名"; exit 1; fi
	./scripts/new-history.sh "$(SLUG)"

new-plan:
	@if [ -z "$(SLUG)" ]; then echo "用法: make new-plan SLUG=计划名"; exit 1; fi
	./scripts/new-exec-plan.sh "$(SLUG)"
