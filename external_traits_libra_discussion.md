# External Traits for Move target
git
External traits cannot be directly translated to Move as, on the Etherum network, they constitute Flint's interface to access the methods exposed by an Etherum contract published at a given address, but Move has no concept of what a contract is. The closest Move get is a module. A solution to this consists in having the user of the external trait define a new module constituting a flint friendly interface in Move for the module it needs to use so that it can be programmatically used in Flint as if it were a contract. Such an interface must define 
- a `Self.T` type, defining an instance of the contract
- a `publish` function, to publish that contract instance on the libra network
- any other public function to operate on an instance of the contract. These functions must
    - take in as the first argument the address that the given contract  instance on which the function is run is published at
    - only have Move's basic types in their signature.