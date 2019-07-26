echo "caller_caps"
swift run flint-test $(FLINTPATH)/utils/testRunner/test_results/test_flint_contracts/caller_caps.tflint
echo "c#########################"

echo "caller_unsat"
swift run flint-test $(FLINTPATH)/utils/testRunner/test_results/test_flint_contracts/caller_unsat.tflint
echo "c#########################"

echo "expression_constructor"
swift run flint-test $(FLINTPATH)/utils/testRunner/test_results/test_flint_contracts/expression_constructor.tflint
echo "c#########################"

echo "failing_test"
swift run flint-test $(FLINTPATH)/utils/testRunner/test_results/test_flint_contracts/failing_test.tflint
echo "c#########################"

echo "series_of_tests"
swift run flint-test $(FLINTPATH)/utils/testRunner/test_results/test_flint_contracts/series_of_tests.tflint
echo "c#########################"

echo "state_test"
swift run flint-test $(FLINTPATH)/utils/testRunner/test_results/test_flint_contracts/state_test.tflint
echo "c#########################"

echo "event"
swift run flint-test $(FLINTPATH)/utils/testRunner/test_results/test_flint_contracts/event.tflint
