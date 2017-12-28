pragma solidity ^0.4.19;

contract Wallet {
  // 0: owner: address
  // 1: contents: uint256
  
  function Wallet() public {
      assembly {
        sstore(0, caller())
      }
  }

  function () public payable {
    assembly {
      switch selector()
      case 0xb6b55f25 /* deposit(uint256) */ {
        deposit(decodeAsUint(0))
      }
      case 0x2e1a7d4d /* withdraw(uint256) */ {
        withdraw(decodeAsUint(0))
      }
      case 0x23677ae2 /* getContents() */ {
        returnUint(getContents())
      }

      function deposit(_ether) {
        sstore(1, add(sload(1), _ether))
      }

      function withdraw(_ether) {
        if not(calledBy(owner())) {
          revert(0, 0)
        }
        sstore(1, sub(sload(1), _ether))
      }
      
      function getContents() -> ret {
        if iszero(calledBy(owner())) {
          revert(0, 0)
        }
        ret := sload(1)
      }

      function selector() -> ret {
        ret := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function decodeAsAddress(offset) -> ret {
        ret := decodeAsUint(offset)
      }

      function decodeAsUint(offset) -> ret {
        ret := calldataload(add(4, mul(offset, 0x20)))
      }

      function calledBy(_address) -> ret {
        ret := eq(_address, caller())
      }

      function owner() -> ret {
        ret := sload(0)
      }

      function returnUint(v) {
        mstore(0, v)
        return(0, 0x20)
      }
    }
  }

}

interface WalletInterface {
  function init(address _address) public;
  function deposit(uint256 _ether) public;
  function withdraw(uint256 _ether) public;
  function getContents() public constant returns (uint _contents);
}

