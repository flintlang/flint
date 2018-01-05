contract Foo {

  function Foo() public {
  }

  function () public payable {
    assembly {
      switch selector()
      
      case 0xc2985578 /* foo() */ {
        returnUInt(foo())
      }
      
      default {
        revert(0, 0)
      }

      // User-defined functions

      function foo() -> ret {
        let a := 2
        a := add(2, 3)
        ret := a
      }

      // Util functions

      function selector() -> ret {
        ret := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }
      
      function decodeAsAddress(offset) -> ret {
        ret := decodeAsUInt(offset)
      }
      
      function decodeAsUInt(offset) -> ret {
        ret := calldataload(add(4, mul(offset, 0x20)))
      }
      
      function calledBy(_address) -> ret {
        ret := eq(_address, caller())
      }
      
      function returnUInt(v) {
        mstore(0, v)
        return(0, 0x20)
      }
    }
  }
}
interface _InterfaceFoo {
  
}