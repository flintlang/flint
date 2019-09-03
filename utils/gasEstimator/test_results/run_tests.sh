swift run flint-ca -gu "$(cat ~/.flint/utils/gasEstimator/test_results/flint_contracts/Counter.flint)" "unused" > temp.js
diff generated_files/counter_gas_estimate.js temp.js
rm temp.js

swift run flint-ca -tu "$(cat ~/.flint/utils/gasEstimator/test_results/flint_contracts/Counter.flint)" "unused" > temp.dot
diff generated_files/counter_typestate_diagram.dot temp.dot
rm temp.dot

swift run flint-ca -cu "$(cat ~/.flint/utils/gasEstimator/test_results/flint_contracts/Counter.flint)" "unused" > temp.json
diff generated_files/counter_caller_analysis.json temp.json
rm temp.json
