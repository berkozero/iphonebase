.PHONY: build release install test test-device test-all clean

# Swift Testing framework path (ships with Command Line Tools, not in default search path)
TESTING_FW = /Library/Developer/CommandLineTools/Library/Developer/Frameworks

build:
	swift build

release:
	swift build -c release

install: release
	cp .build/release/iphonebase /usr/local/bin/

test:
	swift test \
		-Xswiftc -F -Xswiftc $(TESTING_FW) \
		-Xlinker -F -Xlinker $(TESTING_FW) \
		-Xlinker -rpath -Xlinker $(TESTING_FW) \
		--enable-swift-testing --disable-xctest

test-device: build
	@bash tests/smoke-test.sh

test-all: test test-device

clean:
	swift package clean
