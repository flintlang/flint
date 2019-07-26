#!/usr/bin/env python3
# -*- coding: utf-8 -*-

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

        elif 'Warning in' in line[:10]:
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
    return fail_lines, warning_lines


contract_verify_result = {}
def test_contract(contract_path, fail_lines, warning_lines):
    run_args = [
            flintc,
            "-g", # Only verify
            contract_path
            ]
    finished_verify = subprocess.run(run_args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        (failed_verification_lines, warning_verification_lines) = parse_flint_errors(str(finished_verify.stdout, 'utf-8'))

        if len(fail_lines) == 0:
            expected_return_code = finished_verify.returncode == 0
        else:
            expected_return_code = finished_verify.returncode != 0

        # Store result
        contract_verify_result[contract_path] = (expected_return_code and failed_verification_lines == fail_lines and warning_verification_lines == warning_lines)
        if verbose:
            if contract_verify_result[contract_path]:
                print(f"{contract_path}: ✔ passed")
            else:
                print(f"{contract_path}:\n fail_lines = {fail_lines !r:>23} failed = {failed_verification_lines !r:>20}\n"
                      f" warning_lines = {warning_lines !r:>20} warned = {warning_verification_lines !r:>20}")
                print("❌ failed\n")
    except Exception as e:
        if verbose:
            print(f"Exception on run, assuming contract fail: {e}")
        # Store result
        contract_verify_result[contract_path]  = False


test_contracts = [
    join(test_contracts_folder, f)
    for f in listdir(test_contracts_folder)
    if isfile(join(test_contracts_folder, f)) and not f.startswith('.') and f.endswith('.flint')
]


def batch(iterable, n=1):
    length = len(iterable)
    for ndx in range(0, length, n):
        yield iterable[ndx:min(ndx + n, length)]


# Read in from command line
list_failed = False
list_skipped = False
list_passed = False
verbose = False
try:
    opts, args = getopt.getopt(sys.argv[1:],"fspv",["list-failed","list-skipped", "list-passed", "verbose"])
    for opt, arg in opts:
        if opt in ("-f", "--list-failed"):
            list_failed = True
        elif opt in ("-s", "--list-skipped"):
            list_skipped = True
        elif opt in ("-p", "--list-passed"):
            list_passed = True
        elif opt in ("-v", "--verbose"):
            verbose = True
            print("Note: Verbose output has been enabled")
except getopt.GetoptError:
    print('run_verifier_tests.py [-f|--list-failed] [-s|--list-skipped] [-p|--list-passed] [-v|--verbose]')
    sys.exit(2)

# Start jobs
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

print("Verification tests")
print("Passed: %i" % len(passed))
if list_passed:
    for passed in passed:
        print("\tPass: %s" % passed)
print("Skipped: %i" % len(skipped))
if list_skipped:
    for skip in skipped:
        print("\tSkip: %s" % skip)
print("Failed: %i" % len(failed))
if list_failed:
    for fail in failed:
        print("\tFail: %s" % fail)
print("Total: %i" % len(test_contracts))

if len(failed):
    sys.exit(min(255, len(failed)))  # Error on failures to stop make test passing
else:
    print("\nAll verification tests succeeded 🥳")
