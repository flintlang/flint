all:
	swift build	

release:
	swift build	-c release
	zip -j flintc.zip .build/release/flintc

test: all
	swift run lite
	cd Tests/BehaviorTests && ./run.sh
