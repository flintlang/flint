all: 
	cp -r Sources/stdlib .build/debug/
	swift build	

release:
	cp -r Sources/stdlib .build/release/
	swift build	-c release --static-swift-stdlib

zip:
	zip -j flintc.zip .build/release/flintc

test: release
	cd Tests/BehaviorTests && ./compile_behavior_tests.sh
	swift run -c release lite 
