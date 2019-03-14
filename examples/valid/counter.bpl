var count: int;

procedure init_Counter()
  modifies count;
{
  count := 0;
}

procedure getCount_Counter() returns (c: int)
{
  c := count;
}

procedure increment_Counter()
  modifies count
{
  // safe addition
  count := count + 1;

  // unsafe addition
  if (count > 2 ^ 256) {
    count := count % (2 ^ 256) // need to define %
  }
}
