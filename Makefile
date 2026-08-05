.PHONY: build install uninstall clean release

APP_NAME = SnipTool
BUNDLE = $(APP_NAME).app
BUILD_DIR = .build/release
VERSION = 1.0.0

build:
	swift build -c release
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/sniptool $(BUNDLE)/Contents/MacOS/sniptool
	cp Info.plist $(BUNDLE)/Contents/
	codesign --force --sign - $(BUNDLE)

install: build
	cp -r $(BUNDLE) /Applications/

uninstall:
	rm -rf /Applications/$(BUNDLE)

clean:
	swift package clean
	rm -rf $(BUNDLE)

release: build
	tar -czf sniptool-$(VERSION)-macos.tar.gz $(BUNDLE)
	shasum -a 256 sniptool-$(VERSION)-macos.tar.gz
