all:
	swift build	

test: all
	swift run lite
	cd Tests/BehaviorTests && ./run.sh
