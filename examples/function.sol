contract Test {

  function Test() public {
  }

  function () public payable {
    assembly {
      switch selector()
      
      case 0x04bc52f8 /* foo(uint256,uint256) */ {
        foo(decodeAsUInt(0), decodeAsUInt(1))
      }
      
      case 0xae42e951 /* bar(uint256,uint256) */ {
        returnUInt(bar(decodeAsUInt(0), decodeAsUInt(1)))
      }
      
      case 0x3bc5de30 /* getData() */ {
        returnUInt(getData())
      }
      
      default {
        revert(0, 0)
      }

      // User-defined functions

      function foo(_a, _b)  {
        let _tmp := bar(_a, _b)
        _tmp := add(_tmp, 1)
        sstore(0, add(_tmp, sload(0)))
      }
      
      function bar(_a, _b) -> ret {
        ret := add(_a, _b)
      }
      
      function getData() -> ret {
        ret := sload(0)
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
interface _InterfaceTest {
  function foo(uint256 a, uint256 b)  public;
  function getData() constant public returns (uint256 ret);
}