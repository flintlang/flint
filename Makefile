all:
	swift build	

test: all
	swift run lite
