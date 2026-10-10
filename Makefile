PREFIX ?= /usr/local
BINARY = symbolreel

.PHONY: build install uninstall test clean

build:
	swift build -c release --disable-sandbox

install: build
	mkdir -p "$(PREFIX)/bin"
	install -m 755 ".build/release/$(BINARY)" "$(PREFIX)/bin/$(BINARY)"

uninstall:
	rm -f "$(PREFIX)/bin/$(BINARY)"

test:
	swift test

clean:
	swift package clean
