APP_NAME = ClaudeMonitor
SCHEME = ClaudeMonitor
BUILD_DIR = build
DMG_NAME = $(APP_NAME).dmg

.PHONY: build dmg clean

build:
	xcodebuild -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		CONFIGURATION_BUILD_DIR=$(CURDIR)/$(BUILD_DIR) \
		build

dmg: build
	hdiutil create -volname $(APP_NAME) \
		-srcfolder $(BUILD_DIR)/$(APP_NAME).app \
		-ov -format UDZO \
		$(BUILD_DIR)/$(DMG_NAME)
	@echo "DMG created: $(BUILD_DIR)/$(DMG_NAME)"

clean:
	rm -rf $(BUILD_DIR)
	xcodebuild -scheme $(SCHEME) clean 2>/dev/null || true
