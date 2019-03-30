type Address = int;
var owner: Address;
var caller: Address;

var owners: [int]Address;
var owners2: [int]Address;

var arr: [int]int;
var arr2: [int]int;
var numWrites: int;

type T1;
const unique Ta: T1;
const unique Tb: T1;
const unique Tc: T1;

procedure Test_init()
  modifies owner;
  modifies numWrites;
  modifies caller;
{
  havoc caller;
  owner := caller;
  // numWrites := 0; // specify inital value of variable - doesn't matter
}

procedure Test_increaseNumWrites()
  requires numWrites >= 0;
  modifies numWrites;
  ensures numWrites > old(numWrites);
{
  assert (exists x: T1 ::  x == Tb);
  numWrites := numWrites + 1;
}

procedure Test_write(index: int, val: int)
  requires numWrites >= 0;
  requires 0 <= index;
  requires index < 4;
  modifies arr;
  modifies numWrites; // call increases numWrites
{
  arr[index] := val;
  call Test_increaseNumWrites();
}

procedure Test_value(index: int) returns (result: int)
  requires 0 <= index;
  requires index < 4;
{
  result := arr[index];
}

procedure Test_value2(index: int) returns (result: int)
  requires 0 <= index;
  requires index < 10;
{
  result := arr2[index];
}

procedure write2(index: int, val: int)
  requires numWrites >= 0;
  requires 0 <= index;
  requires index < 10;
  modifies arr2;
  modifies numWrites; // call increases numWrites
{
  arr2[index] := val;
  call Test_increaseNumWrites();
}

procedure valueBoth(index: int) returns (result: int)
  requires 0 <= index;
  requires index < 4;
  requires 0 <= index;
  requires index < 10;
{
  result := arr[index] + arr2[index];
}

procedure numWrites() returns (result: int)
{
  result := numWrites;
}
