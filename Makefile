all:
	swift build	

release:
	swift build	-c release

test: all
	swift run lite
	cd Tests/BehaviorTests && ./run.sh
