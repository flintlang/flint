all:
	swift build
	cp -r stdlib .build/debug/

release:
	swift build	-c release --static-swift-stdlib
	cp -r stdlib .build/release/

zip: release
	cp .build/release/flintc flintc
	zip -r flintc.zip flintc stdlib
	rm flintc

test: lint release
	cd Tests/BehaviorTests && ./compile_behavior_tests.sh
	swift run -c release lite

.PHONY: lint
lint:
	swiftlint lint
