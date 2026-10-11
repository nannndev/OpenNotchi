# OpenNotchi monorepo
#   apps/macos    macOS app (Swift)
#   apps/website  landing page (React + Vite)
#   brand         logo, icon and brand assets

MACOS := apps/macos
WEB := apps/website

.PHONY: help app run install dist clean web web-install web-build brand release

help:
	@echo "make run                  build and launch the macOS app (debug)"
	@echo "make app                  release build of the macOS app"
	@echo "make install              release build, copied to /Applications"
	@echo "make dist                 universal .dmg + .zip in $(MACOS)/dist"
	@echo "make web                  run the website locally"
	@echo "make web-build            production build of the website"
	@echo "make brand                regenerate icon, logo and web assets"
	@echo "make release VERSION=x.y.z  tag a release (CI publishes it)"

app:
	$(MAKE) -C $(MACOS) build

run:
	$(MAKE) -C $(MACOS) run

install:
	$(MAKE) -C $(MACOS) install

dist:
	$(MAKE) -C $(MACOS) dist

clean:
	$(MAKE) -C $(MACOS) clean
	rm -rf $(WEB)/dist

web-install:
	npm --prefix $(WEB) ci

web: web-install
	npm --prefix $(WEB) run dev

web-build: web-install
	npm --prefix $(WEB) run build

brand:
	swift brand/generate.swift

release:
	$(MAKE) -C $(MACOS) release VERSION=$(VERSION)
