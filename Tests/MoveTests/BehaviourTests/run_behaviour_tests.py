#!/usr/bin/python3
import re
from pathlib import Path
from typing import NamedTuple, Optional, List, Iterable
import subprocess, os, sys, shutil
from contextlib import contextmanager


class CompilationError(Exception): ...
class FlintCompilationError(CompilationError): ...
class MoveRuntimeError(RuntimeError): ...


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

    def __str__(self):
        with open(self.path) as file:
            return file.read()

    def __lshift__(self, other):
        # Require the two programmes to be of the same type before joining them
        assert type(self) == type(other)
        with open(TestRunner.default_path / "temp" / self.path.name, "w") as file:
            file.write(str(self) + "\n" + str(other))

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
            raise MoveRuntimeError(output)

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
{ self !s}

script:
{ testsuite !s}
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
            f"./.build/debug/flintc",
            "--target", "move", "--no-stdlib", "--emit-ir", "--skip-verifier", str(self.path)
        ], stdout=subprocess.PIPE)
        output = process.stdout.read()
        if b"Produced binary" not in output:
            raise FlintCompilationError(output.decode("utf8"))
        return MoveIRProgramme(Path("./bin/main.mvir"))


class BehaviourTest(NamedTuple):
    programme: FlintProgramme
    testsuite: Optional[MoveIRProgramme] = None

    @classmethod
    def from_name(cls, name: str):
        move_path = TestRunner.default_path / (name + ".mvir")
        move_programme = None
        if move_path.exists():
            move_programme = MoveIRProgramme(move_path)

        return BehaviourTest(
            FlintProgramme(TestRunner.default_path / (name + ".flint")),
            move_programme
        )

    def test(self) -> bool:
        try:
            test = self.programme.compile()
        except FlintCompilationError as e:
            TestFormatter.failed(self.programme.name, str(e))
            return False
        if self.testsuite:
            test.with_testsuite(self.testsuite)

        test.move_to_libra()
        try:
            test.run()
        except MoveRuntimeError as e:
            TestFormatter.failed(self.programme.name, str(e))
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
        print(f"{cls.FAIL}Failed tests{cls.END}")
        for test in tests:
            print(f"\t{cls.FAIL}{test.programme.path}{cls.END}")

    @classmethod
    def complete(cls):
        print(f"\n\t{cls.SUCCESS}All MoveIR tests passed!{cls.END}\n")


class TestRunner(NamedTuple):
    tests: List[BehaviourTest]
    default_path = Path("Tests/MoveTests/BehaviourTests/tests")

    @classmethod
    def from_all(cls):
        return TestRunner([BehaviourTest.from_name(file.stem)
                           for file in cls.default_path.iterdir()
                           if file.suffix.endswith("flint")])

    def run(self):
        passed = set()
        for test in self.tests:
            try:
                if test.test():
                    passed.add(test)
            except BaseException as e:
                print(f"Unexpected error `{e}`. Assuming failure")
                raise e from e

        shutil.rmtree(MoveIRProgramme.libra_path / MoveIRProgramme.temporary_test_path)
        shutil.rmtree(self.default_path / "temp")

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
        print("MoveIR tests not yet configured on this computer")
        sys.exit(0)
    sys.exit(TestRunner.from_all().run())
