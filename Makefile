all:
	swift build	

test:
	swift test
	swift run lite
	./test_compiles.sh
