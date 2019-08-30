# Reflections on the task of correctly translating Flint's external traits for the Libra blockchain


External traits cannot be directly translated to Move as, on the Etherum network, they provide an interface to access the methods exposed by an Etherum contract published at a given address, but Move has no concept of what a contract is. The closest Move get is a module. A solution to this consists in having the user of the external trait define a flint friendly interface in Move for the module it needs to use so that it can be programatically used in Flint as if it were an contract. Such an interface 

## Types
## User-defined Interface