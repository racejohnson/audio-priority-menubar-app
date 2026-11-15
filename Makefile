SWIFT := /usr/bin/swift
NAME := Audio Priority
BUNDLE_ID := com.racejohnson.audio-priority
APP := .build/$(NAME).app
INSTALLED := /Applications/$(NAME).app

.PHONY: all test app install run dry-run snapshot selftest readme icon clean

all: test app

test:
	$(SWIFT) test

app:
	$(SWIFT) build -c release --product AudioPriority
	/bin/rm -rf "$(APP)"
	/bin/mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	/bin/cp "$$($(SWIFT) build -c release --show-bin-path)/AudioPriority" "$(APP)/Contents/MacOS/AudioPriority"
	/bin/cp AppResources/Info.plist "$(APP)/Contents/Info.plist"
	if [ -f AppResources/AppIcon.icns ]; then \
		/bin/cp AppResources/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"; \
	fi
	if [ -f AppResources/Assets.car ]; then \
		/bin/cp AppResources/Assets.car "$(APP)/Contents/Resources/Assets.car"; \
	fi
	/bin/cp LICENSE "$(APP)/Contents/Resources/LICENSE"
	/usr/bin/codesign --force --sign - --timestamp=none "$(APP)"
	/usr/bin/codesign --verify --deep --strict --verbose=2 "$(APP)"

# Quits the running copy and waits (up to 5 s) for it to exit before replacing the bundle.
install: app
	-/usr/bin/osascript -e 'if application id "$(BUNDLE_ID)" is running then tell application id "$(BUNDLE_ID)" to quit'
	-@for i in $$(seq 1 50); do /usr/bin/pgrep -xq AudioPriority || break; /bin/sleep 0.1; done
	/bin/rm -rf "$(INSTALLED)"
	/usr/bin/ditto "$(APP)" "$(INSTALLED)"
	/usr/bin/codesign --verify --deep --strict --verbose=2 "$(INSTALLED)"
	/usr/bin/open "$(INSTALLED)"

# Quits the installed copy first: the app refuses to run beside another copy of itself.
run: app
	-/usr/bin/osascript -e 'if application id "$(BUNDLE_ID)" is running then tell application id "$(BUNDLE_ID)" to quit'
	-@for i in $$(seq 1 50); do /usr/bin/pgrep -xq AudioPriority || break; /bin/sleep 0.1; done
	/usr/bin/open "$(APP)"

# Runs the app without changing the Mac's audio devices or its saved settings:
# it reads the real devices, decides, and only logs what it would have switched.
dry-run: app
	AUDIO_PRIORITY_DRY_RUN=1 "$(APP)/Contents/MacOS/AudioPriority"

# Writes PNGs of the panel and the menu-bar capsule to .build/snapshots, from
# the real devices, without showing a window or switching anything.
snapshot: app
	AUDIO_PRIORITY_DRY_RUN=1 "$(APP)/Contents/MacOS/AudioPriority" --snapshot .build/snapshots

# Opens the real panel and drives it with synthetic clicks (a row, a drag, the
# slider), as a dry run, then reports. Keep your hands off for five seconds.
selftest: app
	AUDIO_PRIORITY_DRY_RUN=1 "$(APP)/Contents/MacOS/AudioPriority" --selftest .build/snapshots

# Redraws the README's pictures in docs/readme from made-up devices, so they
# do not depend on what is plugged in. Needs rsvg-convert for the app icon.
readme: app
	AUDIO_PRIORITY_DRY_RUN=1 "$(APP)/Contents/MacOS/AudioPriority" --readme docs/readme
	rsvg-convert -w 256 -h 256 Icon/AppIcon.svg -o docs/readme/icon.png

icon:
	Icon/build-icon.sh

clean:
	$(SWIFT) package clean
	/bin/rm -rf "$(APP)"
