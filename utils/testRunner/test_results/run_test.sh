swift run flint-test -t /Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner/test_results/test_flint_contracts/caller_caps.tflint  > temp.js
diff generated_js_files/caller_caps.js temp.js
rm temp.js

swift run flint-test -t /Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner/test_results/test_flint_contracts/caller_unsat.tflint  > temp.js
diff generated_js_files/caller_unsat.js temp.js
rm temp.js

swift run flint-test -t /Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner/test_results/test_flint_contracts/expression_constructor.tflint  > temp.js
diff generated_js_files/expression_constructor.js temp.js
rm temp.js

swift run flint-test -t /Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner/test_results/test_flint_contracts/failing_test.tflint  > temp.js
diff generated_js_files/failing_test.js temp.js
rm temp.js

swift run flint-test -t /Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner/test_results/test_flint_contracts/series_of_tests.tflint  > temp.js
diff generated_js_files/series_of_tests.js temp.js
rm temp.js

swift run flint-test -t /Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner/test_results/test_flint_contracts/state_test.tflint  > temp.js
diff generated_js_files/state_test.js temp.js
rm temp.js
