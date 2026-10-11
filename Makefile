.PHONY: build debug run clean install

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
	rm -rf .build build
