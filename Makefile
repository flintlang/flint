all:
	swift build	

release:
	swift build	-c release --static-swift-stdlib

zip:
	zip -j flintc.zip .build/release/flintc

test:
	swift build -c release
	swift run -c release lite 
	cd Tests/BehaviorTests && ./run_behavior_tests.sh
