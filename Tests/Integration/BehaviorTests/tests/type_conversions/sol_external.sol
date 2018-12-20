pragma solidity ^0.4.21;

contract External {

    constructor() public {
    }

    function testReduce(uint256 _value) public pure returns (uint128) {
      return uint128(_value);
    }

    function testIncrease(uint128 _value) public pure returns (uint256) {
      return uint256(_value);
    }
}

