pragma solidity ^0.4.21;

contract Returner {
    constructor() public {
    
    }

    function goodFunction(uint8 _value) public pure returns (uint8) {
        return _value + 7;
    }

    function badFunction(uint8 _value) public pure returns (uint8) {
        require(false);
        return _value;
    }
}

