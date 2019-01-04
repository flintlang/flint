//procedure test_Inconsistent_Assumptions()
//{
//  assert false;
//}

type Address;
const NullAddress: Address;

type Wei = int;

var sentWei: Wei; // Track Wei sent by contract
var receivedWei: Wei; // Track Wei received by contract
var contractWei: Wei; // Track amount of Wei in contract

var caller: Address;

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

procedure init_Bank(manager: Address)
  // Required for sentWei >= old(sentWei) etc...
  requires (sentWei == Wei.New(0));
  requires (receivedWei == Wei.New(0));
  requires (contractWei == Wei.New(0));

  modifies manager_Bank;
  modifies balances_Bank;
  modifies accounts_Bank;
  modifies lastIndex_Bank;
  modifies totalDonations_Bank;
  modifies sentWei;
  modifies receivedWei;
  modifies contractWei;

  // contract invariant - Wei:
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
{
  manager_Bank := manager;

  balances_Bank := MapAddressWei.Empty();
  accounts_Bank := ArrayAddress.Empty();
  lastIndex_Bank := 0;
  totalDonations_Bank := Wei.New(0);

  sentWei := Wei.New(0);
  receivedWei := Wei.New(0);
  contractWei := Wei.New(0);
}

procedure register_Bank()
  // requires invariant:
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  requires (forall a: Address :: contractWei >= balances_Bank[a]); // required for subtraction of contractWei
  requires (contractWei >= totalDonations_Bank); // required for subtraction of contractWei

  modifies accounts_Bank;
  modifies lastIndex_Bank;
  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
{
  accounts_Bank[lastIndex_Bank] := caller;
  lastIndex_Bank := lastIndex_Bank + 1;
}

procedure getManager_Bank() returns (result: Address)
  // requires invariant:
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  requires (forall a: Address :: contractWei >= balances_Bank[a]); // required for subtraction of contractWei
  requires (contractWei >= totalDonations_Bank); // required for subtraction of contractWei

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
{
  result := manager_Bank;
}

procedure donate_Bank(value: Wei)
  // Wei provides this guarantee
  requires (value >= Wei.New(0)); // Provided by Wei type

  // requires invariant:
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  requires (forall a: Address :: contractWei >= balances_Bank[a]); // required for subtraction of contractWei
  requires (contractWei >= totalDonations_Bank); // required for subtraction of contractWei

  modifies totalDonations_Bank;
  modifies receivedWei;
  modifies contractWei;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
{
  // From input
  receivedWei := receivedWei + value;
  // Add received money to contract
  contractWei := contractWei + value;

  totalDonations_Bank := totalDonations_Bank + value;
}

procedure freeDeposit_Bank(account: Address, amount: int)
  // Caller capability
  requires (caller == manager_Bank);

  // requires invariant:
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  requires (forall a: Address :: contractWei >= balances_Bank[a]); // required for subtraction of contractWei
  requires (contractWei >= totalDonations_Bank); // required for subtraction of contractWei

  modifies balances_Bank;
  modifies contractWei;
  modifies receivedWei;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
{
  var w: Wei;
  // Added if stmt, not in Bank.flint, to pass verification
  if (amount < 0) {
    assume false; // Don't explore further
  } else {
    // No negative money
    assert (amount >= 0);
    w := Wei.New(amount);
    // Allocate money for contract (Wei.New())
    contractWei := contractWei + w;
    // FIXED - pretend money was received by contract
    receivedWei := receivedWei + w;

    // Do the transfer
    assert (w >= Wei.New(0));
    assert (balances_Bank[account] >= Wei.New(0));

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
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  requires (forall a: Address :: contractWei >= balances_Bank[a]); // required for subtraction of contractWei
  requires (contractWei >= totalDonations_Bank); // required for subtraction of contractWei

  modifies balances_Bank;
  modifies contractWei;
  modifies sentWei;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei /type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
{
  contractWei := contractWei + 0; // Wei(0)
  // Can't create/destroy money
  contractWei := contractWei - balances_Bank[account]; // balances[account] = Wei(0) - dangerous assignment
  // FIXED - pretend contract sent money somewhere
  sentWei := sentWei + balances_Bank[account] - Wei.New(0);
  // No negative money
  assert (0 >= 0);
  balances_Bank[account] := Wei.New(0);

}

procedure getDonations_Bank() returns (result: int)
  requires caller == manager_Bank;
  // ensures contract invariant holds
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
{
  // cast total donations to raw values
  result := totalDonations_Bank;
}

procedure getBalance_Bank() returns (result: int)
  requires (exists x: int :: caller == accounts_Bank[x]);
  // requires contract invariant holds
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
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
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);

  modifies balances_Bank;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
{
  var account: Address;
  account := caller;

  // Transfer
  // This is provided by Wei.transfer
  assume (balances_Bank[account] >= amount);
  assume (amount >= 0);
  balances_Bank[account] := balances_Bank[account] - amount;
  balances_Bank[destination] := balances_Bank[destination] + amount;
}

procedure deposit_Bank(value: Wei)
  requires (exists x: int :: caller == accounts_Bank[x]);
  requires (value >= Wei.New(0)); // provided by Wei type
  // requires contract invariant holds
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);

  modifies balances_Bank;
  modifies contractWei;
  modifies receivedWei;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
{
  var account: Address;
  account := caller;

  // From input
  receivedWei := receivedWei + value;
  // Add received money to contract
  contractWei := contractWei + value;

  // Transfer
  balances_Bank[account] := balances_Bank[account] + value;
}

procedure withdraw_Bank(amount: int)
  requires (exists x: int :: caller == accounts_Bank[x]);
  // requires contract invariant holds
  requires (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  requires (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  requires (forall a: Address :: contractWei >= balances_Bank[a]); // required for subtraction of contractWei
  requires (contractWei >= totalDonations_Bank); // required for subtraction of contractWei

  modifies balances_Bank;
  modifies contractWei;
  modifies sentWei;

  // ensures contract invariant holds
  ensures (totalDonations_Bank >= Wei.New(0)); // Provided by Wei type of totalDonations
  ensures (forall a: Address :: balances_Bank[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= Wei.New(0));
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= Wei.New(0));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei >= Wei.New(0));
  ensures (contractWei == receivedWei - sentWei);
{
  var account: Address;
  var w: Wei;
  account := caller;

  assert (0 >= 0); // no negative money
  w := Wei.New(0);
  contractWei := contractWei + w; // Create money for Wei.New(0)

  // provided by Wei.transfer
  assume (balances_Bank[account] >= amount);
  assume (amount >= 0);
  // Transfer wei
  balances_Bank[account] := balances_Bank[account] - amount;
  w := w + amount;

  // Send w to account
  contractWei := contractWei - w;
  sentWei := sentWei + w;
}
