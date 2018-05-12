all: 
	mkdir -p .build/debug
	cp -r stdlib .build/debug/
	swift build	

release:
	mkdir -p .build/debug
	cp -r stdlib .build/release/
	swift build	-c release --static-swift-stdlib

zip: release
	cp .build/release/flintc flintc
	zip -r flintc.zip flintc stdlib
	rm flintc

test: release
	cd Tests/BehaviorTests && ./compile_behavior_tests.sh
	swift run -c release lite 
