# Solidity Translated Case Studies

These case studies are taken from the [Solidity by Example](https://solidity.readthedocs.io/en/v0.4.24/solidity-by-example.html) section of the Solidity documentation. We compare the original solidity code to its equivalent in idiomatic Flint, and explain both the differences between Flint and Solidity and explore the features available within Flint.

## Voting

This contract aims to implement an electronic voting system, whereby designated voters can cast their vote for one of several proposals, or instead opt to delegate their vote to another participant. The winning proposal at any given time is the proposal with the largest number of accumulated votes.

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

As Flint does not support complex external call arguments or return values,
