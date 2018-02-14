all:
	swift build	

release:
	swift build	-c release

test: release
	swift run lite
	cd Tests/BehaviorTests && ./run.sh
