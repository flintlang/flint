(for F in examples/casestudies/*.flint; do
  echo "$F" >&2;
  /usr/bin/time -f"%e" --quiet .build/debug/flintc --quiet -g $F;
  #/usr/bin/time -f"%e" --quiet .build/debug/flintc --quiet -g --skip-verifier $F;
done) 2> data.txt > rawOutput.txt
