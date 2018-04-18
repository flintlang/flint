all:
	swift build	

release:
	swift build	-c release --static-swift-stdlib

zip:
	zip -j flintc.zip .build/release/flintc

test:
	swift build -c release
	cd Tests/BehaviorTests && ./compile_behavior_tests.sh
	swift run -c release lite 
