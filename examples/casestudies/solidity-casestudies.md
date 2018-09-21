# Solidity Translated Case Studies

These case studies are taken from the [Solidity by Example](https://solidity.readthedocs.io/en/v0.4.24/solidity-by-example.html) section of the Solidity documentation. We compare the original solidity code to its equivalent in idiomatic Flint, and explain both the differences between Flint and Solidity and explore the features available within Flint.

## Voting

This contract aims to implement an electronic voting system, whereby designated voters can cast their vote for one of several proposals, or instead opt to delegate their vote to another participant. Voters can be designated by the *chairperson*, which is the ethereum address that created the Ballot contract. The winning proposal at any given time is the proposal with the largest number of accumulated votes.

## Defining the Contract

Flint:
```swift
contract Ballot (Proposing, Voting) {
  // The administrator of the ballot.
  visible let chairperson: Address

  // The accounts which have voted in this ballot.
  var voters: [Address: Voter] = [:]
  visible var votersKeys: [Address] = [] // this can be removed once keys property of dictionary is added to stdlib

  // The list of proposals.
  var proposals: [Proposal] = []
}
```

Solidity:
```javascript
contract Ballot {
    // struct definitions ...

    address public chairperson;

    // This declares a state variable that
    // stores a `Voter` struct for each possible address.
    mapping(address => Voter) public voters;

    // A dynamically-sized array of `Proposal` structs.
    Proposal[] public proposals;

	// initialiser and function declarations ...
}
```

In the Flint code, the Ballot contract is declared as a stateful contract, having two states, `Proposing` and `Voting`. These *type states* allow the behaviour of the contract to be more clearly defined, and ensure that voting will not be able to take place until all the proposals have been added, for example. The initial state of the contract will be set in the initialiser.

Solidity contracts can contain definitions for structures, which Flint does not support, as structures are defined globally instead. In addition, contract functions and initialisers in Flint are defined in separate *protection blocks* enclosing functions in the same contract that share the same sets of possible states and *caller capabilities*.

Declaring *state properties* of the contract is similar in both Solidity and Flint, although the syntax differs slightly. Solidity `mapping`s compare to Flint *dictionaries*, declared as `[KeyType: ValueType]`, and Flint's dynamically sized arrays are similarly declared as `[ElementType]`. State properties in Flint are private by default following the general private-first ideology of the language, so the `visible` modifier is added to all the properties, allowing the compiler to generate getter functions for each one. Flint does not presently support struct return types for external functions so only `chairperson` can be made visible. The `public` keyword plays a similar role in the Solidity code.

For `voters`, `votersKeys`, and `proposals`, a default value is provided in the Flint code, meaning these properties to not have to be explicitly initialised in the initialiser.

## Initialisation

Flint:
```swift
Ballot@(any) :: caller <- (any) {
	public init() {
		chairperson = caller

		// Chairperson is a normal voter.
		voters[chairperson] = Voter(1)
		votersKeys[0] = chairperson

		become Proposing
	}
}

Ballot@(Proposing) :: (chairperson) {
	// Add a proposal to the list of proposals to vote on.
	public mutating func addProposal(proposalName: String) {
		proposals[proposals.size] = Proposal(proposalName)
	}

	// Begin the voting phase.
	public mutating func beginVote() {
		become Voting
	}
}
```

Solidity:
```javascript
/// Create a new ballot to choose one of `proposalNames`.
constructor(bytes32[] proposalNames) public {
	chairperson = msg.sender;
	voters[chairperson].weight = 1;

	// For each of the provided proposal names,
	// create a new proposal object and add it
	// to the end of the array.
	for (uint i = 0; i < proposalNames.length; i++) {
		// `Proposal({...})` creates a temporary
		// Proposal object and `proposals.push(...)`
		// appends it to the end of `proposals`.
		proposals.push(Proposal({
			name: proposalNames[i],
			voteCount: 0
		}));
	}
}
```

The `init` function in Flint must be publicly declared in a universal restriction block. This is because the state of a contract is undefined before the `init` function is called, and therefore accessing the *type state* and *caller capabilities* would be invalid. All properties that were not given default values in the contract must be initialised, and the state must also be set to its initial value, in this case `Proposing`. The state may only be set once in each function, with a `become` statement at the very end of the function declaration.

In Flint, the address of the external caller is bound at the start of the restriction block, in this case to the identifier `caller`, which can be used in functions inside the restriction block. In Solidity, the caller address is stored as a global variable, which is not as easy to use or intuitive. The address stored inside `chairperson` then becomes the

As Flint does not support complex external call arguments or return values, the init function does not take any arguments and simply sets the chairperson Address. *Type states* are used to implement an initialisation phase so that proposals can only be added before voting is enabled.

## Voter Designation

Flint:
```swift
Ballot@(Proposing) :: (chairperson) {
	// Allow an address to vote.
	public mutating func giveRightToVote(voter: Address) {
		// Ensure the voter has not been initialised yet, by checking the weight.
		assert(voters[voter].votingWeight == 0)

		// Create voter and add to dictionary.
		voters[voter] = Voter(1)
		votersKeys[votersKeys.size] = voter
	}
```

Solidity:
```javascript
// Give `voter` the right to vote on this ballot.
// May only be called by `chairperson`.
function giveRightToVote(address voter) public {
	// If the first argument of `require` evaluates
	// to `false`, execution terminates and all
	// changes to the state and to Ether balances
	// are reverted.
	// This used to consume all gas in old EVM versions, but
	// not anymore.
	// It is often a good idea to use `require` to check if
	// functions are called correctly.
	// As a second argument, you can also provide an
	// explanation about what went wrong.
	require(
		msg.sender == chairperson,
		"Only chairperson can give right to vote."
	);
	require(
		!voters[voter].voted,
		"The voter already voted."
	);
	require(voters[voter].weight == 0);
	voters[voter].weight = 1;
}
```

The Flint implementation of this function uses both *type states* and *caller capabilities* to avoid manual checking of preconditions. The function can only be called when the contract is in the `Proposing` state, and only by the address stored in the `chairperson` property of the contract. As it is not possible to cast a vote during the `Proposing` phase, there is no need to check if the `Voter` has already voted. Neither is it required to check the caller identity due to the caller capability in the protection block.

However, in Flint it is necessary to check if the current `Voter` has already been initialised manually. This is done by checking the `voterWeight` of the Voter, as this will always be >0 if the struct has been initialised. `assert`s in Flint are similar to Solidity's `require` function, and the transaction will be reverted if the condition given is not true.

Flint's structures have initialiser functions so the voter is added to the dictionary using `Voter(1)`, where 1 is the `voterWeight`. In Solidity initialisation is optional but in Flint it is required (although not currently strictly enforced).

## Delegation of Votes

Flint:
```swift
Ballot@(Voting) :: voter <- (votersKeys) {
  // Delegate vote to another voter.
  public mutating func delegate(target: Address) {
    // Ensure the delegator has not already voted, the delegator is not the delegate,
    // and that the delegate has the right to vote.
    assert((voters[voter].hasVoted == false) && (voter != target) && (voters[target].votingWeight != 0))

    // Delegating to a delegate that itself delegates is not allowed, as loops could be formed and
    // unbounded gas consumption is possible. This must be checked explicitly as otherwise votes
    // would be sent to an incorrect proposal.
    assert(voters[target].delegate == 0x0000000000000000000000000000000000000000)

    voters[voter].hasVoted = true
    voters[voter].delegate = target

    // The voting weight of the caller.
    let voterWeight: Int = voters[voter].votingWeight

    // Increase the weight of the delegate.
    voters[target].votingWeight += voterWeight

    if voters[target].hasVoted {
      // If the delegate has already voted for a proposal, increase its number of votes.

      // The proposal the delegate has voted for.
      var votedProposalID: Int = voters[target].votedProposalID // TODO: this should be let, but is var due to a bug.
      proposals[votedProposalID].numVotes += voterWeight
    }
  }
}
```

Solidity:
```javascript
/// Delegate your vote to the voter `to`.
function delegate(address to) public {
	// assigns reference
	Voter storage sender = voters[msg.sender];
	require(!sender.voted, "You already voted.");

	require(to != msg.sender, "Self-delegation is disallowed.");

	// Forward the delegation as long as
	// `to` also delegated.
	// In general, such loops are very dangerous,
	// because if they run too long, they might
	// need more gas than is available in a block.
	// In this case, the delegation will not be executed,
	// but in other situations, such loops might
	// cause a contract to get "stuck" completely.
	while (voters[to].delegate != address(0)) {
		to = voters[to].delegate;

		// We found a loop in the delegation, not allowed.
		require(to != msg.sender, "Found loop in delegation.");
	}

	// Since `sender` is a reference, this
	// modifies `voters[msg.sender].voted`
	sender.voted = true;
	sender.delegate = to;
	Voter storage delegate_ = voters[to];
	if (delegate_.voted) {
		// If the delegate already voted,
		// directly add to the number of votes
		proposals[delegate_.vote].voteCount += sender.weight;
	} else {
		// If the delegate did not vote yet,
		// add to her weight.
		delegate_.weight += sender.weight;
	}
}
```
