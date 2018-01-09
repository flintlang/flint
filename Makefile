all:
	swift build	

test:
	swift run lite
	./test_compiles.sh
