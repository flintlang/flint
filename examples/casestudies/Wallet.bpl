type Address;
const NullAddress: Address;

type Wei = int;
function Wei.New(value: int) returns (result: Wei);
axiom (forall i, j: int :: i >= 0 && j >= 0 && i == j <==> Wei.New(i) == Wei.New(j));
axiom (forall i, j: int :: i > j <==> Wei.New(i) > Wei.New(j));
axiom (forall i, j, k: int :: i + j == k <==> Wei.New(i) + Wei.New(j) == Wei.New(k));

var caller: Address;

var owner: Address;
var contents: Wei;

procedure init_Wallet()
  modifies owner;
  modifies contents;
  ensures (contents >= Wei.New(0));
{
  owner := caller;
  contents := Wei.New(0);
}

procedure deposit(value: Wei)
  requires (true); // TODO pre condition
  requires (value >= Wei.New(0)); // Wei type
  requires (contents >= Wei.New(0));
  modifies contents;
  ensures (contents >= Wei.New(0));
  ensures (true); // TODO post condition
{
  contents := contents + value;
}

procedure withdraw(value: int)
  requires (caller == owner_Wallet);
  requires (contents >= Wei.New(0));
  modifies contents;
  ensures (contents >= Wei.New(0));
  ensures (true); // TODO post condition
{
  var w: Wei;
  assert (value >= 0); // no negative money
  w := Wei.New(value);

  assume (w <= contents); // error would be thrown by runtime
  contents := contents - w;

  // TODO Send w to owner
}

procedure getContents_Wallet() returns (result: int)
  requires (caller == owner_Wallet);
  requires (contents >= Wei.New(0));
  ensures (contents >= Wei.New(0));
  ensures (true); // TODO post condition
{
  result := contents;
}
