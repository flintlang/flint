BOOGIE_EXE=boogie/Binaries/Boogie.exe
SYMBOOGLIX_EXE=symbooglix/src/SymbooglixDriver/bin/Release/sbx.exe
Z3=z3/build/z3
Boogie_Z3_slink=boogie/Binaries/z3.exe
Symbooglix_Z3_slink=symbooglix/src/SymbooglixDriver/bin/Release/z3.exe
Z3_SYSTEM_PATH = $(shell which z3)
RELEASE_EXECUTABLES=flintc flint-test flint-repl flint-ca flint-lsp
.PHONY: all debug release zip test lint generate-sources generate-mocks test-nogen clean

all: generate-sources $(BOOGIE_EXE) $(SYMBOOGLIX_EXE) debug

debug: generate-sources
	swift build $(BUILD_ARGS)
	cp -r stdlib .build/debug/

release: generate-sources $(BOOGIE_EXE) $(SYMBOOGLIX_EXE)
	swift build -c release $(BUILD_ARGS)
	cp -r stdlib .build/release/

xcode:
	swift package generate-xcodeproj

run:
	swift build $(TARGET_FLAGS)
	swift run dev_version

zip: release
	for EXECUTABLE in $(RELEASE_EXECUTABLES); do \
		cp .build/release/$$EXECUTABLE $$EXECUTABLE; \
	done
	zip -r flintc.zip $(RELEASE_EXECUTABLES) stdlib
	rm $(RELEASE_EXECUTABLES)

test: lint generate-mocks release
	sed -i -e "s/ as / as! /g" .build/checkouts/Cuckoo/Source/Initialization/ThreadLocal.swift
	swift test
	cd Tests/Integration/BehaviorTests && ./compile_behavior_tests.sh
	./Tests/VerifierTests/run_verifier_tests.py -vf
	./Tests/MoveTests/BehaviourTests/run_behaviour_tests.py
	swift run -c release lite

test-lite:
	cd Tests/Integration/BehaviorTests && ./compile_behavior_tests.sh
	swift run -c release lite

test-nogen: lint release
	swift test
	cd Tests/Integration/BehaviorTests && ./compile_behavior_tests.sh
	./Tests/VerifierTests/run_verifier_tests.py -vf
	swift run -c release lite

lint:
	swiftlint lint --strict

generate-mocks:
	 swift package resolve
	./generate_mocks.sh

generate-sources: Sources/AST/ASTPass/ASTPass.generated.swift
Sources/AST/ASTPass/ASTPass.generated.swift:
	cd utils/codegen && npm install && cd ../..
	./utils/codegen/codegen.js

$(SYMBOOGLIX_EXE): $(Symbooglix_Z3_slink)
	cd symbooglix/src && (test -f nuget.exe || wget https://nuget.org/nuget.exe) \
	  && mono ./nuget.exe restore Symbooglix.sln \
	  && msbuild Symbooglix.sln /p:Configuration=Release /verbosity:quiet \
	  && cd ../..

$(BOOGIE_EXE): $(Boogie_Z3_slink)
	cd boogie && (test -f nuget.exe || wget https://nuget.org/nuget.exe) \
	  && mono ./nuget.exe restore Source/Boogie.sln \
	  && msbuild Source/Boogie.sln /verbosity:quiet && cd ..

$(Boogie_Z3_slink): $(Z3)
	cd boogie \
	  && (test -L Binaries/z3.exe || ln -s ../../$(Z3) Binaries/z3.exe) \
	  && cd .. \

$(Symbooglix_Z3_slink): $(Z3)
	cd symbooglix \
	  && (test -L src/SymbooglixDriver/bin/Release/z3.exe || (mkdir -p src/SymbooglixDriver/bin/Release && ln -sf ../../../../../$(Z3) src/SymbooglixDriver/bin/Release/z3.exe)) \
	  && (test -L src/Symbooglix/bin/Release/z3.exe || (mkdir -p src/Symbooglix/bin/Release/z3.exe && ln -sf ../../../../../$(Z3) src/Symbooglix/bin/Release/z3.exe)) \
	  && cd ..

$(Z3):
	mkdir -p z3/build/
	ln -sf $(Z3_SYSTEM_PATH) $(Z3)
#	cd z3 && python scripts/mk_make.py --prefix=$(pwd)/bin \
#	  && cd build && make && cd ../..

clean:
	-swift package clean
	-rm -rf .build
	-rm -r .derived-sources
	-rm boogie/Binaries/z3.exe
	-cd boogie && msbuild Source/Boogie.sln /t:Clean && cd ..
	-rm boogie/Binaries/*.{dll,pdb,config}
	-rm $(Symbooglix_Z3_slink)
	-cd symbooglix/src && msbuild /t:Clean && cd ../..
