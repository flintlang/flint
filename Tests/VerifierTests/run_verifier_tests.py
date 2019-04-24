#!/usr/bin/env python

# Locate flint contracts
# Parse contracts
#   - Should they verify or not? (//VERIFY-PASS, //VERIFY-FAIL)
# Check if compiler matches this or not

from os import listdir
from os.path import isfile, join
import subprocess
import sys, getopt
import threading
import re

test_contracts_folder = "Tests/VerifierTests/tests/"
flintc = ".build/debug/flintc"
test_batch_size = 8

def parse_flint_errors(stdout_lines):
    error_lines = set()
    warning_lines = set()
    lines = stdout_lines.split('\n')
    for current_line, line in enumerate(lines):
        if 'Error in' in line:
            error_info_line = lines[current_line + 1] # ... at line 35, column 5
            matches = re.search('at line (?P<flint_line>[0-9]+), column ([0-9]+)', error_info_line)
            error_lines.add(int(matches.group('flint_line')))

        elif 'Warning in' in line:
            warning_info_line = lines[current_line + 1]
            matches = re.search('at line (?P<flint_line>[0-9]+), column ([0-9]+)', warning_info_line)
            if matches is not None:
                warning_lines.add(int(matches.group('flint_line')))

    return (error_lines, warning_lines)

def parse_fail_lines(flint_lines):
    fail_lines = set()
    warning_lines = set()
    for (current_line, line) in enumerate(flint_lines, 1): # Humans count from 1
        line = line.rstrip().strip()
        if line == "//VERIFY-FAIL":
            # The annotation is always placed the line of interest
            fail_lines.add(current_line + 1)
        elif line == "//VERIFY-WARNING":
            warning_lines.add(current_line + 1)

        current_line += 1
    return (fail_lines, warning_lines)


contract_verify_result = {}
def test_contract(contract_path, fail_lines, warning_lines):
    runArgs = [
            flintc,
            "-g", # Only verify
            contract_path
            ]
    finished_verify = subprocess.run(runArgs, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    (failed_verification_lines, warning_verification_lines) = parse_flint_errors(str(finished_verify.stdout, 'utf-8'))

    if len(fail_lines) == 0:
        expected_return_code = finished_verify.returncode == 0
    else:
        expected_return_code = finished_verify.returncode != 0

    # Store result
    contract_verify_result[contract_path]  = (expected_return_code and failed_verification_lines == fail_lines and warning_verification_lines == warning_lines)

test_contracts = [join(test_contracts_folder, f) for f in listdir(test_contracts_folder) \
        if isfile(join(test_contracts_folder, f)) and not f.startswith('.') and f.endswith('.flint')]

def batch(iterable, n = 1):
    l = len(iterable)
    for ndx in range(0, l, n):
        yield iterable[ndx:min(ndx + n, l)]

skipped = []
pending_jobs = []
for contract in test_contracts:
    with open(contract, 'r') as c:
        lines = c.readlines()
        should_check = "VERIFY-CHECK" in lines[0]

        if not should_check: # No first line or malformed one
            skipped.append(contract)
            continue

        (fail_lines, warning_lines) = parse_fail_lines(lines)
        pending_jobs.append(threading.Thread(target=test_contract, args=(contract, fail_lines, warning_lines)))

# Wait until all tests are completed
for job_batch in batch(pending_jobs, test_batch_size):
    for job in job_batch:
        job.start()
    for job in job_batch:
        job.join()

passed = []
failed = []
for contract, result in contract_verify_result.items():
    if result:
        passed.append(contract)
    else:
        failed.append(contract)

list_failed = False
list_skipped = False
try:
    opts, args = getopt.getopt(sys.argv[1:],"fs",["list-failed","list-skipped"])
    for opt, arg in opts:
        if opt in ("-f", "--list-failed"):
            list_failed = True
        elif opt in ("-s", "--list-skipped"):
            list_skipped = True
except getopt.GetoptError:
    print('run_verifier_tests.py [-f|--list-failed] [-s|--list-skipped]')
    sys.exit(2)

print("Verification tests")
print("Total: %i" % len(test_contracts))
print("Passed: %i" % len(passed))
print("Skipped: %i" % len(skipped))
if list_skipped:
    for skip in skipped:
        print("\tSkip: %s" % skip)
print("Failed: %i" % len(failed))
if list_failed:
    for fail in failed:
        print("\tFail: %s" % fail)
