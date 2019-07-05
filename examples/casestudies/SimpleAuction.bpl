
function DIV(i: real, j: real) returns (result: real);
axiom (forall i, j: real :: i >= real(0) && j > real(0) ==> DIV(i, j) >= real(0));

function MOD(i: real, j: real) returns (result: real);
axiom (forall i, j: real :: i >= real(0) && j > real(0) ==> MOD(i, j) >= real(0));

type Address;
const NullAddress: Address;

var sentWei: Wei; // Track Wei sent by contract
var receivedWei: Wei; // Track Wei received by contract
var contractWei: Wei; // Track amount of Wei in contract

var caller: Address;

function Wei.New(value: int) returns (result: Wei);
axiom (forall i, j: int :: i >= 0 && j >= 0 && i == j <==> Wei.New(i) == Wei.New(j));
axiom (forall i, j: int :: i >= 0 && j >= 0 && i == j <==> Wei.New(i) == Wei.New(j));
axiom (forall i, j: int :: i > j <==> Wei.New(i) > Wei.New(j));
axiom (forall i, j, k: int :: i + j == k <==> Wei.New(i) + Wei.New(j) == Wei.New(k));

function MapAddressWei.Empty() returns (result: [Address]Wei);
axiom (forall a: Address :: MapAddressWei.Empty()[a] == Wei.New(0)); // default value

function MapAddressBool.Empty() returns (result: [Address]bool);
axiom (forall a: Address :: MapAddressBool.Empty()[a] == false); // default value

function ArrayInt.Empty() returns (result: [int]int);
axiom (forall i: int :: ArrayInt.Empty()[i] == 0); // default value

function ArrayInt.EmptySize(size: int) returns (result: [int]int);
axiom (forall i, N: int :: 0 <= i && i < N ==> ArrayInt.EmptySize(N)[i] == 0);

function ArrayAddress.Empty() returns (result: [int]Address);
axiom (forall i: int :: ArrayAddress.Empty()[i] == NullAddress); // default value

var beneficiary_SimpleAuction: Address;
var hasAuctionEnded_SimpleAuction: bool;
var highestBidder_SimpleAuction: Address;
var highestBid_SimpleAuction: Wei; // Index to Wei

procedure init_SimpleAuction()
  modifies beneficiary_SimpleAuction;
  modifies highestBidder_SimpleAuction;
  modifies hasAuctionEnded_SimpleAuction;
  modifies highestBidder_SimpleAuction;
  ensures (true); // TODO contract post condition holds
{
  beneficiary_SimpleAuction := caller;
  highestBidder_SimpleAuction := caller;

  hasAuctionEnded_SimpleAuction := false;
  highestBid_SimpleAuction := Wei.New(0);
}

procedure big_SimpleAuction(value: Wei)
  requires (true); // TODO pre-conditions
  ensures (true); // TODO post-conditions
{
  if (hasAuctionEnded_SimpleAuction) {
    assume false;
  }
  if (value <= highestBid_SimpleAuction) {
    assume false;
  }

  if (highestBid_SimpleAuction > 0) {
    sentWei := sentWei + highestBid_SimpleAuction;
    contractWei := contractWei - highestBid_SimpleAuction;
  }

  highestBidder_SimpleAuction := caller;
  assert (value >= 0);
  highestBid := value;
  //value := 0; // Can't modify arguments
}

procedure getHighestBid_SimpleAuction() returns (result: int)
  requires (true); // TODO pre-conditions
  ensures (true); // TODO post-conditions
{
  result := highestBid_SimpleAuction;
}

procedure getHighestBidder_SimpleAuction() returns (result: Address)
  requires (true); // TODO pre-conditions
  ensures (true); // TODO post-conditions
{
  result := highestBidder_SimpleAuction;
}

procedure endAuction_SimpleAuction()
  requires (caller == beneficiary_SimpleAuction);
  requires (true); // TODO pre-conditions
  ensures (true); // TODO post-conditions
{
  if (hasAuctionEnded_SimpleAuction) {
    assume (false);
  }

  hasAuctionEnded_SimpleAuction := true;

  sentWei := sentWei + highestBid_SimpleAuction;
  contractWei := contractWei - highestBid_SimpleAuction;
  highestBid_SimpleAuction := Wei.New(0);
}
