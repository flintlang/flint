#!/usr/bin/env python3

# - diff failing scripts with previous run
# - select failing script and run
#   - select whether to pipe stderr to tmp file to make debugging easier
# - re-build project

import subprocess

failing_verification_translation_sh="./utils/failing_verification_translation.sh"

def run_verifier():
    finished_failed_programs = subprocess.run([failing_verification_translation_sh], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

    output = str(finished_failed_programs.stdout, 'utf8').rstrip()
    return output.split('\n')[2:]

def print_failing_selection(failing_contracts):
    for i, contract in enumerate(failing_contracts):
        print("%i: %s" % (i, contract))

def debug_contract(contract_location):
    debugRunArgs = [
            ".build/debug/flintc",
            "--dump-verifier-ir",
            contract_location
            ]
    finished_debug = subprocess.run(debugRunArgs, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return (str(finished_debug.stdout, 'utf8'), str(finished_debug.stderr, 'utf8'))

def rebuild():
    finished_rebuild = subprocess.run(['make'])

## Print number passing + failing
#print(output.split('\n')[0])
#print()

failing_contracts = run_verifier()
dump_std_err = False
other_options = ['re-check-all', 're-build', 'toggle dump stderr']
while True:
    print("Dump StdErr = %d" % dump_std_err)
    print("# of failing contracts: %d" % len(failing_contracts))

    print_failing_selection(failing_contracts + other_options)

    rawInput = input("Enter # to debug: ")
    if len(rawInput) == 0:
        continue
    selection = int(rawInput)

    if selection < len(failing_contracts):
        (stdout, stderr) = debug_contract(failing_contracts[selection])
        print(stdout)
        if dump_std_err:
            print(stderr)
    else:
        selection %= len(failing_contracts)
        if selection == 0:
            failing_contracts = run_verifier()
        elif selection == 1:
            rebuild()
        elif selection == 2:
            dump_std_err = not dump_std_err
