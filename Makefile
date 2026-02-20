.PHONY: build release install test clean

build:
	swift build

release:
	swift build -c release

install: release
	cp .build/release/iphonebase /usr/local/bin/

test:
	swift test

clean:
	swift package clean
