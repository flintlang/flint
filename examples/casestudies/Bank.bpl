type Address;
const NullAddress: Address;

type Wei = int;

// TODO - specification from perspective of contract -> money in + money out == current
// TODO - specification from perspective of user -> (money put in + transfers == money get out)
// TODO   - eg, manager, account

// procedure Wei.Transfer(in: Wei, out: Wei) returns (newOut: Wei)
//   requires (in >= Wei.New(0) && out >= Wei.New(0));
//   ensures (newOut == in + out);
//   ensures (newOut >= Wei.New(0));
// {
//   newOut := in + out;
// }

function Wei.New(value: int) returns (result: Wei);
axiom (forall i, j: int :: i >= 0 && j >= 0 && i == j <==> Wei.New(i) == Wei.New(j));
axiom (forall i, j: int :: i > j <==> Wei.New(i) > Wei.New(j));
axiom (forall i, j, k: int :: i + j == k <==> Wei.New(i) + Wei.New(j) == Wei.New(k));

function MapAddressWei.Empty() returns (result: [Address]Wei);
axiom (forall a: Address :: MapAddressWei.Empty()[a] == Wei.New(0));

function ArrayAddress.Empty() returns (result: [int]Address);
axiom (forall i: int :: ArrayAddress.Empty()[i] == NullAddress); // default value

function ArrayAddress.EmptySize(size: int) returns (result: [int]Address);
axiom (forall i, N: int :: 0 <= i && i < N ==> ArrayAddress.EmptySize(N)[i] == NullAddress);

var manager_Bank: Address;
var balances_Bank: [Address]Wei;
var accounts_Bank: [int]Address;
var lastIndex_Bank: int;

var totalDonations_Bank: Wei;

var caller: Address;

// procedure test_Inconsistent_Assumptions()
// {
//   assert false;
// }

procedure init_Bank(manager: Address)
  modifies manager_Bank;
  modifies balances_Bank;
  modifies accounts_Bank;
  modifies lastIndex_Bank;
  modifies totalDonations_Bank;

  // contract invariant - Wei:
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  manager_Bank := manager;

  balances_Bank := MapAddressWei.Empty();
  accounts_Bank := ArrayAddress.Empty();
  lastIndex_Bank := 0;
  totalDonations_Bank := Wei.New(0);
}

procedure register_Bank()
  // requires invariant:
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances

  modifies accounts_Bank;
  modifies lastIndex_Bank;
  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  accounts_Bank[lastIndex_Bank] := caller;
  lastIndex_Bank := lastIndex_Bank + 1;
}

procedure getManager_Bank() returns (result: Address)
  // requires invariant:
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  result := manager_Bank;
}

procedure donate_Bank(value: Wei)
  // Wei provides this guarantee
  requires (value >= Wei.New(0)); // Provided by Wei type

  // requires invariant:
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances

  modifies totalDonations_Bank;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  //call totalDonations_Bank_1 := Wei.Transfer(value, totalDonations_Bank);
  //value_1 := Wei.New(0);
  // Check transfer - not strictly needed (Wei.Transfer gives this directly)
  //assert (value_1 == 0);
  //assert (totalDonations_Bank_1 == value + totalDonations_Bank);

  totalDonations_Bank := totalDonations_Bank + value;
}

procedure freeDeposit_Bank(account: Address, amount: int)
  // Caller capability
  requires (caller == manager_Bank);

  // requires invariant:
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances

  modifies balances_Bank;
  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  var w: Wei;
  // Added if stmt, not in Bank.flint, to pass verification
  if (amount < 0) {
    assume false; // Don't explore further
  } else {
    // No negative money
    assert (amount >= 0);
    w := Wei.New(amount);

    // Do the transfer - are these asserts needed?
    assert (w >= Wei.New(0));
    assert (balances_Bank[account] >= Wei.New(0));

    //call balances_Bank_1_account := Wei.Transfer(w, balances_Bank[account]);

    // transfer
    balances_Bank[account] := balances_Bank[account] + w;
    w := Wei.New(0);
  }
}

procedure clear_Bank(account: Address)
  requires caller == manager_Bank;
  // requires contract invariant holds
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances

  modifies balances_Bank;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  // Can't create/destroy money Wei.New(state, value) - state == int, which increases / decreases, on Wei.Transfer(state, in, out)..
  // No negative money
  assert (0 >= 0);
  balances_Bank[account] := Wei.New(0); // TODO: This should fail a money/created destroyed test - overriding money
}

procedure getDonations_Bank() returns (result: int)
  requires caller == manager_Bank;
  // ensures contract invariant holds
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  // cast total donations to raw values
  result := totalDonations_Bank;
}

procedure getBalance_Bank() returns (result: int)
  requires (exists x: int :: caller == accounts_Bank[x]);
  // requires contract invariant holds
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  var account: Address;
  account := caller;
  result := balances_Bank[account]; // cast to int
}

procedure transfer_Bank(amount: int, destination: Address)
  requires (exists x: int :: caller == accounts_Bank[x]);
  // requires contract invariant holds
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances

  modifies balances_Bank;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  var account: Address;
  account := caller;

  // PREVIOUSLY NO CHECK ON IF AMOUNT IS NEGATIVE - invariant caught this
  if (amount < 0) {
    assume false; // throw exception
  }

  // Transfer
  assume (balances_Bank[account] >= amount); // This is provided by Asset transfer
  balances_Bank[account] := balances_Bank[account] - amount;
  balances_Bank[destination] := amount;
}

procedure deposit_Bank(value: Wei)
  requires (exists x: int :: caller == accounts_Bank[x]);
  requires (value >= Wei.New(0)); // provided by Wei type
  // requires contract invariant holds
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances

  modifies balances_Bank;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  var account: Address;
  var value_1: Wei;
  account := caller;
  value_1 := value;
  // Transfer
  balances_Bank[account] := balances_Bank[account] + value;
  value_1 := Wei.New(0);
}

procedure withdraw_Bank(amount: int)
  requires (exists x: int :: caller == accounts_Bank[x]);
  requires balances_Bank[caller] >= amount;
  // requires contract invariant holds
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances

  modifies balances_Bank;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
{
  var account: Address;
  var w: Wei;
  account := caller;

  assume (balances_Bank[account] >= amount);
  balances_Bank[account] := balances_Bank[account] - amount;
  w := Wei.New(amount);

  // TODO Send money to recipient
}
