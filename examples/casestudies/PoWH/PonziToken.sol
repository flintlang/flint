// Cutdown PonziToken to just show vulnerability

pragma solidity ^0.4.11;

contract PonziToken {
	uint256 public totalSupply;
	// amount of shares for each address (scaled number)
	mapping(address => uint256) public balanceOf;
	// allowance map, see erc20
	mapping(address => mapping(address => uint256)) public allowance;

	function PonziToken() {
		owner = msg.sender;
	}

	function transferFrom(address _from, address _to, uint256 _value) {
      var _allowance = allowance[_from][msg.sender];
      if (_allowance < _value)
          throw;
      allowance[_from][msg.sender] = _allowance - _value;
      transferTokens(_from, _to, _value);
  }

	function transferTokens(address _from, address _to, uint256 _value) internal {
		if (balanceOf[_from] < _value)
			throw;
		if (_to == address(this)) {
			sell(_value);
		} else {
		    // Omitted as not relevant to vulnerability
		}
	}

	function sell(uint256 amount) internal {
		// remove tokens
		totalSupply -= amount;
		balanceOf[msg.sender] -= amount;
	}
}
