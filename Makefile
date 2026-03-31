APP_NAME = ClaudeMonitor
SCHEME = ClaudeMonitor
BUILD_DIR = build
ARCHIVE = $(BUILD_DIR)/$(APP_NAME).xcarchive
DMG_NAME = $(APP_NAME).dmg
TEAM_ID = BV2S7MJ6PR
NOTARY_PROFILE = notarytool-profile

.PHONY: build archive export dmg notarize release clean

# --- Dev build (unsigned) ---
build:
	xcodebuild -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		CONFIGURATION_BUILD_DIR=$(CURDIR)/$(BUILD_DIR) \
		build

# --- Signed archive ---
archive:
	xcodebuild -scheme $(SCHEME) -configuration Release \
		-archivePath $(ARCHIVE) \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		CODE_SIGN_STYLE=Automatic \
		archive

# --- Export signed .app from archive ---
export: archive
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE) \
		-exportPath $(BUILD_DIR) \
		-exportOptionsPlist ExportOptions.plist

# --- Create DMG with Applications shortcut ---
dmg: export
	rm -rf $(BUILD_DIR)/dmg-staging
	mkdir -p $(BUILD_DIR)/dmg-staging
	cp -R $(BUILD_DIR)/$(APP_NAME).app $(BUILD_DIR)/dmg-staging/
	ln -s /Applications $(BUILD_DIR)/dmg-staging/Applications
	hdiutil create -volname $(APP_NAME) \
		-srcfolder $(BUILD_DIR)/dmg-staging \
		-ov -format UDZO \
		$(BUILD_DIR)/$(DMG_NAME)
	rm -rf $(BUILD_DIR)/dmg-staging
	@echo "DMG created: $(BUILD_DIR)/$(DMG_NAME)"

# --- Notarize + staple ---
notarize: dmg
	xcrun notarytool submit $(BUILD_DIR)/$(DMG_NAME) \
		--keychain-profile $(NOTARY_PROFILE) \
		--wait
	xcrun stapler staple $(BUILD_DIR)/$(DMG_NAME)
	@echo "Notarized and stapled: $(BUILD_DIR)/$(DMG_NAME)"

# --- Full release pipeline ---
release: notarize
	@echo "Ready to distribute: $(BUILD_DIR)/$(DMG_NAME)"

# --- Clean ---
clean:
	rm -rf $(BUILD_DIR)
	xcodebuild -scheme $(SCHEME) clean 2>/dev/null || true
