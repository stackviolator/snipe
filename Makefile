.PHONY: build install uninstall clean release

APP_NAME = Snipe
BUNDLE = $(APP_NAME).app
BUILD_DIR = .build/release
VERSION = 2.0.0

build:
	swift build -c release
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/snipe $(BUNDLE)/Contents/MacOS/snipe
	cp Info.plist $(BUNDLE)/Contents/
	@if [ -f AppIcon.icns ]; then cp AppIcon.icns $(BUNDLE)/Contents/Resources/; fi
	codesign --force --sign - $(BUNDLE)

install: build
	cp -r $(BUNDLE) /Applications/

uninstall:
	rm -rf /Applications/$(BUNDLE)

clean:
	swift package clean
	rm -rf $(BUNDLE)

release: build
	tar -czf snipe-$(VERSION)-macos.tar.gz $(BUNDLE)
	shasum -a 256 snipe-$(VERSION)-macos.tar.gz
