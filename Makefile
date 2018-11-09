all: generate
	swift build
	cp -r stdlib .build/debug/

.PHONY: all release zip test lint generate-sources generate-mocks test-nogen

release: generate-sources
	swift build	-c release --static-swift-stdlib
	cp -r stdlib .build/release/

zip: release
	cp .build/release/flintc flintc
	zip -r flintc.zip flintc stdlib
	rm flintc

test: lint generate-mocks release
	swift test
	cd Tests/Integration/BehaviorTests && ./compile_behavior_tests.sh
	swift run -c release lite

test-nogen: lint release
	swift test
	cd Tests/Integration/BehaviorTests && ./compile_behavior_tests.sh
	swift run -c release lite

lint:
	swiftlint lint --strict

generate-mocks:
	 swift package resolve
	./generate_mocks.sh

generate-sources:
	./utils/codegen/codegen.js
