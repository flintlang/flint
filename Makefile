all: 
	swift build	

release:
	swift build	-c release --static-swift-stdlib

zip:
	zip -j flintc.zip .build/release/flintc

test:
	export FLINT_STDLIB=/Users/fschrans/git/flint/Sources/stdlib
	swift build -c release
	cd Tests/BehaviorTests && ./compile_behavior_tests.sh
	swift run -c release lite 
