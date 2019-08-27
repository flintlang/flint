#!/usr/bin/python3
import re
from pathlib import Path
from typing import NamedTuple, Optional, List, Iterable
import subprocess, os, sys, shutil
from contextlib import contextmanager


class CompilationError(Exception): ...
class FlintCompilationError(CompilationError): ...


class MoveRuntimeError(RuntimeError):
    def __init__(self, message, line=None):
        self.line = line
        super().__init__(message)

    @classmethod
    def from_output(cls, output):
        line = re.search(r"Aborted\((\d+)\)", output)
        if line:
            line = int(line.group(1))
        return cls(output, line)


@contextmanager
def run_at_path(path):
    original_dir = os.getcwd()
    if isinstance(path, str):
        path = Path(path)
    os.chdir(path.expanduser())
    yield
    os.chdir(original_dir)


class Programme:
    path: Path

    def __init__(self, path):
        self.path = path

    def contents(self):
        with open(self.path) as file:
            return file.read()

    @property
    def name(self):
        return self.path.stem


class MoveIRProgramme(Programme):
    libra_path = Path("libra")
    temporary_test_path = Path("language/functional_tests/tests/testsuite/flinttemp")

    def run(self):
        with run_at_path(self.libra_path):
            process = subprocess.Popen(
                ["cargo", "test", "-p", "functional_tests", "/".join(list(self.path.parts)[-2:])],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
        output = process.stdout.read().decode("utf8") + process.stderr.read().decode("utf8")
        if re.search(r"[^0\s]\s+failed", output) or not re.search(r"[1-9]\s+passed", output):
            raise MoveRuntimeError.from_output(output)

    def with_testsuite(self, testsuite):
        assert isinstance(testsuite, MoveIRProgramme)
        new = TestRunner.default_path / "temp" / self.path.name
        try:
            os.makedirs(TestRunner.default_path / "temp")
        except FileExistsError:
            pass
        with open(new, "w") as file:
            file.write(f"""\
modules:
{ self.contents() !s}

script:
{ testsuite.contents() !s}
""")
        self.path = new

    def move_to_libra(self):
        testpath = self.libra_path / self.temporary_test_path / self.path.parts[-1]
        try:
            os.makedirs(self.libra_path / self.temporary_test_path)
        except FileExistsError:
            pass
        else:
            print(f"Created new folder {testpath} for testfile")
        self.path.rename(testpath)
        self.path = testpath


class FlintProgramme(Programme):
    def compile(self) -> MoveIRProgramme:
        process = subprocess.Popen([
            f"./.build/release/flintc",
            "--target", "move", "--no-stdlib", "--emit-ir", "--skip-verifier", str(self.path)
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output = process.stdout.read() + process.stderr.read()
        if b"Produced binary" not in output:
            raise FlintCompilationError(output.decode("utf8"))
        return MoveIRProgramme(Path("./bin/main.mvir"))


class BehaviourTest(NamedTuple):
    programme: FlintProgramme
    testsuite: Optional[MoveIRProgramme] = None
    expected_fail_line: Optional[int] = None

    @classmethod
    def from_name(cls, name: str):
        """
        Creates a behaviour test from a test name, searching for .flint and .mvir files
        The .flint file must exist, however the .mvir file is optional (it will just
        check compilation in such case).

        If you want your test to fail on an assertion on line x in Flint, you can write
        `// expect fail x`, however, this expects the assertion to have that line number
        which may not be the case if the assertion is generated through fatalErrors or
        similar functions. It will work if a disallowed operation (type states, caller
        protections) has been attempted. Also note, only one fail is allowed per test.
        """

        move_path = TestRunner.default_path / (name + ".mvir")
        move_programme = None
        expected_fail_line = None
        if move_path.exists():
            move_programme = MoveIRProgramme(move_path)
            expect_fail = re.search(r"// expect fail (\d+)", move_programme.contents(), flags=re.IGNORECASE)
            if expect_fail:
                expected_fail_line = int(expect_fail.group(1))

        return cls(
            FlintProgramme(TestRunner.default_path / (name + ".flint")),
            move_programme,
            expected_fail_line
        )

    def test(self) -> bool:
        try:
            test = self.programme.compile()
        except FlintCompilationError as e:
            TestFormatter.failed(self.programme.name, f"Flint Compilation Error: `{e !s}`")
            return False
        if self.testsuite:
            test.with_testsuite(self.testsuite)

        test.move_to_libra()
        try:
            test.run()
        except MoveRuntimeError as e:
            line, message = e.line, f"Move Runtime Error: " \
                f"Error in {self.programme.path.name} line {e.line}: {e !s}"
        else:
            line, message = None, f"Move Missing Error: " \
                f"No error raised in {self.programme.path.name} line {self.expected_fail_line}"
        if self.expected_fail_line != line:
            TestFormatter.failed(self.programme.name, message)
            return False
        TestFormatter.passed(self.programme.name)
        return True


class TestFormatter:
    FAIL = "\033[1;38;5;196m"
    SUCCESS = "\033[1;38;5;114m"
    END = "\033[m"
    @classmethod
    def failed(cls, test, message):
        print(f"""\
{test}: {cls.FAIL}failed{cls.END}
\t{message}\
""")

    @classmethod
    def passed(cls, test):
        print(f"{test}: {cls.SUCCESS}passed{cls.END}")

    @classmethod
    def all_failed(cls, tests: Iterable[BehaviourTest]):
        print(f"{cls.FAIL}Failed tests:{cls.END}")
        for test in tests:
            print(f"\t{cls.FAIL}{test.programme.path}{cls.END}")

    @classmethod
    def complete(cls):
        print(f"\n\t{cls.SUCCESS}All MoveIR tests passed!{cls.END}\n")

    @classmethod
    def not_configured(cls):
        print("""\
MoveIR tests not yet configured on this computer
To run them please symlink `./libra' to your local copy of the libra repository\
""")


class TestRunner(NamedTuple):
    tests: List[BehaviourTest]
    default_path = Path("Tests/MoveTests/BehaviourTests/tests")

    @classmethod
    def from_all(cls, names=[]):
        return TestRunner([BehaviourTest.from_name(file.stem)
                           for file in cls.default_path.iterdir()
                           if file.suffix.endswith("flint")
                           if not names or file.stem in names])

    def run(self):
        passed = set()
        for test in self.tests:
            try:
                if test.test():
                    passed.add(test)
            except BaseException as e:
                print(f"Unexpected error `{e}`. Assuming failure")

        try:
            shutil.rmtree(MoveIRProgramme.libra_path / MoveIRProgramme.temporary_test_path)
            shutil.rmtree(self.default_path / "temp")
        except: pass

        failed = set(self.tests) - passed
        if failed:
            TestFormatter.all_failed(failed)
            return 1
        else:
            TestFormatter.complete()
            return 0


if __name__ == '__main__':
    os.chdir(os.environ['FLINTPATH'])
    if not Path(MoveIRProgramme.libra_path).exists():
        TestFormatter.not_configured()
        sys.exit(0)
    sys.exit(TestRunner.from_all(sys.argv[1:]).run())
