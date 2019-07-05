//procedure test_Inconsistent_Assumptions()
//{
//  assert false;
//}

//axiom (forall x: int, y: int :: { x % y } { x / y } x % y == x - x / y * y);
function DIV(i: real, j: real) returns (result: real);
axiom (forall i, j: real :: i >= real(0) && j > real(0) ==> DIV(i, j) >= real(0));

function MOD(i: real, j: real) returns (result: real);
axiom (forall i, j: real :: i >= real(0) && j > real(0) ==> MOD(i, j) >= real(0));

type Address;
const NullAddress: Address;

type Wei = int;

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

var proposer_Proposal: [int]Address;
var payout_Proposal: [int]int;
var recipient_Proposal: [int]Address;
var yea_Proposal: [int]int;
var nay_Proposal: [int]int;
var finished_Proposal: [int]bool;
var success_Proposal: [int]bool;
var voted_Proposal: [int][Address]bool;
var allocated: [int]bool;
var nextIndex: int;

procedure init_Proposal(proposer: Address, payout: int, recipient: Address) returns (i: int)
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  modifies proposer_Proposal;
  modifies payout_Proposal;
  modifies recipient_Proposal;
  modifies yea_Proposal;
  modifies nay_Proposal;
  modifies finished_Proposal;
  modifies success_Proposal;
  modifies voted_Proposal;
  modifies allocated;
  modifies nextIndex;

  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex > old(nextIndex));
  // creating new struct shouldn't affect other structs - in this case -> not in general
  //ensures (forall j: int :: j < old(nextIndex) ==> allocated[j] && old(allocated)[j]);
  //ensures (forall j: int :: j < old(nextIndex) ==> proposer_Proposal[j] == old(proposer_Proposal)[j]);
  //ensures (forall j: int :: j < old(nextIndex) ==> payout_Proposal[j] == old(payout_Proposal)[j]);
  //ensures (forall j: int :: j < old(nextIndex) ==> recipient_Proposal[j] == old(recipient_Proposal)[j]);
  //ensures (forall j: int :: j < old(nextIndex) ==> yea_Proposal[j] == old(yea_Proposal)[j]);
  //ensures (forall j: int :: j < old(nextIndex) ==> nay_Proposal[j] == old(nay_Proposal)[j]);
  //ensures (forall j: int :: j < old(nextIndex) ==> finished_Proposal[j] == old(finished_Proposal)[j]);
  //ensures (forall j: int :: j < old(nextIndex) ==> success_Proposal[j] == old(success_Proposal)[j]);
  //ensures (forall j: int :: j < old(nextIndex) ==> voted_Proposal[j] == old(voted_Proposal)[j]);
{
  proposer_Proposal[nextIndex] := proposer;
  payout_Proposal[nextIndex] := payout;
  recipient_Proposal[nextIndex] := recipient;
  yea_Proposal[nextIndex] := 0;
  nay_Proposal[nextIndex] := 0;
  finished_Proposal[nextIndex] := false;
  success_Proposal[nextIndex] := false;
  voted_Proposal[nextIndex] := MapAddressBool.Empty();

  allocated[nextIndex] := true;
  nextIndex := nextIndex + 1;
}

var curator_SimpleDAO: Address;
var proposal_SimpleDAO: int;
var proposals_SimpleDAO: [int]int; // int -> index to struct
var proposals_size_SimpleDAO: int;
var balances_SimpleDAO: [Address]Wei;
var balances_keys_SimpleDAO: [int]Address;
var balances_size_SimpleDAO: int;

type State;
const unique Join: State;
const unique Propose: State;
const unique Vote: State;
var currentState: State;

procedure init_SimpleDAO(curator: Address)
  requires (caller == caller);
  // Required for sentWei >= old(sentWei) etc...
  requires (sentWei == Wei.New(0));
  requires (receivedWei == Wei.New(0));
  requires (contractWei == Wei.New(0));
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  modifies curator_SimpleDAO;
  modifies proposal_SimpleDAO;
  modifies proposals_SimpleDAO;
  modifies proposals_size_SimpleDAO;
  modifies balances_SimpleDAO;
  modifies balances_keys_SimpleDAO;
  modifies balances_size_SimpleDAO;
  modifies currentState;

  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // Required for iteration over map
  // TODO: ensures (forall i: int :: (exists a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a ==> balances_SimpleDAO[a] == w));
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));
{
  curator_SimpleDAO := curator;
  currentState := Join;

  proposal_SimpleDAO := 0;
  proposals_SimpleDAO := ArrayInt.Empty();
  proposals_size_SimpleDAO := 0;
  balances_SimpleDAO := MapAddressWei.Empty();
  balances_keys_SimpleDAO := ArrayAddress.Empty();
  balances_size_SimpleDAO := 0;
}

procedure fallback_SimpleDAO()
  requires (caller == caller);
  // contract invariant - Wei:
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  // Required for iteration over map
  // TODO: requires (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: requires (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // Required for iteration over map
  // TODO: ensures (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));
{
  assume false; // throw exception
}

procedure tokenHolder_SimpleDAO(addr: Address) returns (result: bool)
  requires (caller == caller);
  // contract invariant - Wei:
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  // Required for iteration over map
  // TODO: requires (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: requires (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // TODO: ensures (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));

{
  result := balances_SimpleDAO[addr] != 0;
}

procedure getTotalState_SimpleDAO() returns (result: int)
  requires (caller == caller);
  // contract invariant - Wei:
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (contractWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (sentWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  // TODO: requires (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  //requires (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);


  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // TODO: ensures (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));
{
  var sum, balances_counter: int;
  var address: Address;
  sum := 0;
  balances_counter := 0;
  while (balances_counter < balances_size_SimpleDAO)
    invariant (balances_counter >= old(balances_counter));
  {
    address := balances_keys_SimpleDAO[balances_counter];

    sum := sum + balances_SimpleDAO[address];

    balances_counter := balances_counter + 1;
  }
  result := sum;
}

procedure join_SimpleDAO(value: Wei)
  requires (currentState == Join);
  requires (value >= Wei.New(0)); // Provided by Wei input type
  // contract invariant - Wei:
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  // TODO: requires (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  //requires (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  modifies balances_SimpleDAO;

  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // TODO: ensures (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));
{
  balances_SimpleDAO[caller] := balances_SimpleDAO[caller] + value;
}

procedure joinTimeElapsed_SimpleDAO()
  requires (currentState == Join);
  requires (caller == curator_SimpleDAO);
  // contract invariant - Wei:
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  // TODO: requires (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  //requires (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  modifies currentState;

  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // TODO: ensures (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));
{
  currentState := Propose;
}

procedure newProposal_SimpleDAO(value: int, recipient: Address) returns (result: int)
  requires (currentState == Propose);
  requires (proposals_size_SimpleDAO >= 0);
  // contract invariant - Wei:
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  // TODO: requires (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  //requires (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  modifies proposals_SimpleDAO;
  modifies proposals_size_SimpleDAO;
  // Required for call to init_Proposal
  modifies proposer_Proposal;
  modifies payout_Proposal;
  modifies recipient_Proposal;
  modifies yea_Proposal;
  modifies nay_Proposal;
  modifies finished_Proposal;
  modifies success_Proposal;
  modifies voted_Proposal;
  modifies allocated;
  modifies nextIndex;

  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // TODO: ensures (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  ensures (proposals_size_SimpleDAO >= old(proposals_size_SimpleDAO));
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));

{
  var pID, temp1: int;
  var enterFunc: bool;
  // tokenHolder - caller capability - defined as function
  call enterFunc := tokenHolder_SimpleDAO(caller);
  if (!enterFunc) {
    assume false;
  }

  pID := proposals_size_SimpleDAO + 1;
  call temp1 := init_Proposal(caller, value, recipient);
  proposals_SimpleDAO[pID] := temp1;
  proposals_size_SimpleDAO := proposals_size_SimpleDAO + 1;
  result := pID;
}

procedure leave_SimpleDAO()
  requires (currentState == Propose);
  // contract invariant - Wei:
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  // TODO: requires (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  //requires (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  modifies sentWei;
  modifies contractWei;
  modifies balances_SimpleDAO;

  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // TODO: ensures (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));
{
  var enterFunc: bool;
  // tokenHolder - caller capability - defined as function
  call enterFunc := tokenHolder_SimpleDAO(caller);
  if (!enterFunc) {
    assume false;
  }

  sentWei := sentWei + balances_SimpleDAO[caller];
  contractWei := contractWei - balances_SimpleDAO[caller];
  balances_SimpleDAO[caller] := 0;
}

procedure beginVote_SimpleDAO(proposal: int)
  requires (caller == curator_SimpleDAO);
  // contract invariant - Wei:
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  // TODO: requires (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  //requires (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  modifies proposal_SimpleDAO;
  modifies currentState;

  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // TODO: ensures (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));
{
  proposal_SimpleDAO := proposal;
  currentState := Vote;
}

procedure vote_SimpleDAO(approve: bool)
  requires (currentState == Vote);
  // contract invariant - Wei:
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  // TODO: requires (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  //requires (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  modifies yea_Proposal;
  modifies nay_Proposal;
  modifies voted_Proposal;

  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // TODO: ensures (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));
{
  var enterFunc: bool;
  // tokenHolder - caller capability - defined as function
  call enterFunc := tokenHolder_SimpleDAO(caller);
  if (!enterFunc) {
    assume false;
  }

  if (voted_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]][caller]) {
  assume false;
  }

  if (approve) {
    yea_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]] := yea_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]] + balances_SimpleDAO[caller];
  } else {
    nay_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]] := nay_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]] + balances_SimpleDAO[caller];
  }

  voted_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]][caller] := true;
}

procedure executeProposal_SimpleDAO()
  requires (currentState == Vote);
  // contract invariant - Wei:
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  requires (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  requires (sentWei >= Wei.New(0));
  requires (receivedWei >= Wei.New(0));
  requires (contractWei >= Wei.New(0));
  requires (contractWei == receivedWei - sentWei);
  // TODO: requires (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  //requires (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  requires (forall j: int :: j < nextIndex ==> allocated[j]);
  requires (nextIndex >= 0);

  modifies finished_Proposal;
  modifies success_Proposal;
  modifies contractWei;
  modifies sentWei;
  modifies currentState;

  // contract invariant - Wei:
  ensures (forall a: Address :: balances_SimpleDAO[a] >= Wei.New(0)); // Provided by Wei type of balances
  // To ensure no money is lost
  ensures (sentWei >= old(sentWei));
  ensures (receivedWei >= old(receivedWei));
  ensures (contractWei == receivedWei - sentWei);
  // TODO: ensures (forall i: int, a: Address, w: Wei :: balances_keys_SimpleDAO[i] == a <==> balances_SimpleDAO[a] == w);
  // TODO: ensures (balances_size_SimpleDAO >= 0);
  // Well formed struct arrays
  ensures (forall j: int :: j < nextIndex ==> allocated[j]);
  ensures (nextIndex >= 0);
  ensures (nextIndex >= old(nextIndex));
{
  var enterFunc: bool;
  var transfervalue, balances_count: int;
  var rawvalue: real;
  var totalstake, value: Wei;
  // tokenHolder - caller capability - defined as function
  call enterFunc := tokenHolder_SimpleDAO(caller);
  if (!enterFunc) {
    assume false;
  }

  if (caller != proposer_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]] || finished_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]]) {
    assume false;
  }

  finished_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]] := true;

  if (yea_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]] > nay_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]]) {
    success_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]] := true;
    transfervalue := Wei.New(0);
    call totalstake := getTotalState_SimpleDAO();

    balances_count := 0;
    while (balances_count < balances_size_SimpleDAO)
      // TODO: I need to determine what in varients I need to write for loops.
      // loops go inv -> inv.   before -> inv. inv -> after.
      invariant (balances_count >= old(balances_count));
      invariant (transfervalue >= 0);
    {
      value := balances_SimpleDAO[balances_keys_SimpleDAO[balances_count]];
      assume (totalstake >= Wei.New(0));
      assume (value >= Wei.New(0));
      assume (forall i: int :: payout_Proposal[i] >= 0);
      rawvalue := DIV(real(payout_Proposal[proposals_SimpleDAO[proposal_SimpleDAO]] * value), real(totalstake));
      // TODO: Need to determine approach here
      assume (rawvalue >= real(0));
      assume (transfervalue >= 0);
      transfervalue := transfervalue + int(rawvalue);
      assert(transfervalue >= 0);
      rawvalue := real(0);

      balances_count := balances_count + 1;
    }

    assert (transfervalue >= 0);

    contractWei := contractWei - transfervalue;
    sentWei := sentWei + transfervalue;
  }
  currentState := Propose;
}
