BOOGIE_EXE=boogie/Binaries/Boogie.exe
Z3=z3/build/z3
Z3_slink=boogie/Binaries/z3.exe

all: generate $(BOOGIE_EXE)
	swift build
	cp -r stdlib .build/debug/

.PHONY: all release zip test lint generate clean

release: generate $(BOOGIE_EXE)
	swift build	-c release --static-swift-stdlib
	cp -r stdlib .build/release/

zip: release
	cp .build/release/flintc flintc
	zip -r flintc.zip flintc stdlib
	rm flintc

test: lint release
	cd Tests/BehaviorTests && ./compile_behavior_tests.sh
	swift run -c release lite

lint:
	swiftlint lint

generate: .derived-sources/AST/ASTPass/ASTPass.swift

.derived-sources/AST/ASTPass/ASTPass.swift: Sources/AST/ASTPass/ASTPass.template.swift
	cd utils/codegen && npm install && cd ../..
	./utils/codegen/codegen.js

$(BOOGIE_EXE): $(Z3_slink)
	cd boogie && (test -f nuget.exe || wget https://nuget.org/nuget.exe) \
	  && mono ./nuget.exe restore Source/Boogie.sln \
	  && msbuild Source/Boogie.sln /verbosity:quiet && cd ..

$(Z3_slink): $(Z3)
	cd boogie \
	  && (test -L Binaries/z3.exe || ln -s ../../$(Z3) Binaries/z3.exe) \
	  && cd ..

$(Z3):
	cd z3 && python scripts/mk_make.py --prefix=$(pwd)/bin \
	  && cd build && make && cd ../..

clean:
	-swift package clean
	-rm -rf .build
	-rm -r .derived-sources
	-rm boogie/Binaries/z3.exe
	-cd boogie && msbuild Source/Boogie.sln /t:Clean && cd ..
	-rm boogie/Binaries/*.{dll,pdb,config}
	-rm -r z3/build


