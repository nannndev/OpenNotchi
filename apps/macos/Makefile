.PHONY: build debug run clean install release dist

build:
	./scripts/build-app.sh release

debug:
	./scripts/build-app.sh debug

run: debug
	-pkill -x OpenNotchi
	open build/OpenNotchi.app

install: build
	rm -rf /Applications/OpenNotchi.app
	cp -R build/OpenNotchi.app /Applications/

clean:
	rm -rf .build build dist

# Universal (arm64 + x86_64) release build packaged into dist/
dist:
	UNIVERSAL=1 ./scripts/build-app.sh release
	./scripts/package.sh $$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

# make release VERSION=1.2.3
release:
	./scripts/release.sh $(VERSION)
