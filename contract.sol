/**
 *Submitted for verification at BscScan.com on 2022-12-12
 */

// SPDX-License-Identifier: MIT
library SafeMath {
  function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
      uint256 c = a + b;
      if (c < a) return (false, 0);
      return (true, c);
    }
  }

  function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
      if (b > a) return (false, 0);
      return (true, a - b);
    }
  }

  function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
      if (a == 0) return (true, 0);
      uint256 c = a * b;
      if (c / a != b) return (false, 0);
      return (true, c);
    }
  }

  function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
      if (b == 0) return (false, 0);
      return (true, a / b);
    }
  }

  function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
      if (b == 0) return (false, 0);
      return (true, a % b);
    }
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    return a + b;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    return a - b;
  }

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    return a * b;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return a / b;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    return a % b;
  }

  function sub(
    uint256 a,
    uint256 b,
    string memory errorMessage
  ) internal pure returns (uint256) {
    unchecked {
      require(b <= a, errorMessage);
      return a - b;
    }
  }

  function div(
    uint256 a,
    uint256 b,
    string memory errorMessage
  ) internal pure returns (uint256) {
    unchecked {
      require(b > 0, errorMessage);
      return a / b;
    }
  }

  function mod(
    uint256 a,
    uint256 b,
    string memory errorMessage
  ) internal pure returns (uint256) {
    unchecked {
      require(b > 0, errorMessage);
      return a % b;
    }
  }
}

pragma solidity 0.8.17;

abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }

  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }
}

contract Ownable is Context {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor() {
    address msgSender = _msgSender();
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);
  }

  function owner() public view returns (address) {
    return _owner;
  }

  modifier onlyOwner() {
    require(_owner == _msgSender(), 'Ownable: caller is not the owner');
    _;
  }

  function renounceOwnership() public onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
  }

  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0), 'Ownable: new owner is the zero address');
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

interface IERC20 {
  function balanceOf(address account) external view returns (uint256);

  function isPresaleClaimed(address account) external view returns (bool);
}

contract BakedPizza is Context, Ownable {
  using SafeMath for uint256;

  uint256 private devFeeVal = 4;
  address payable private recAdd = payable(0x7864694dFBD21a77d7150f2B3b529B9480B32571);
  uint256 public EGGS_TO_HATCH_1MINERS=2592000;//for final version should be seconds in a day
  uint256 PSN=10000;
  uint256 PSNH=5000;
  bool public initialized=false;
  mapping (address => uint256) public hatcheryMiners;
  mapping (address => uint256) public claimedEggs;
  mapping (address => uint256) public lastHatch;
  mapping (address => address) public referrals;
  uint256 public marketEggs;
  uint8 public tradingState = 0;
  IERC20 token;

  constructor(address _owner, address _token) {
    setToken(_token);
    transferOwnership(_owner);
  }

  modifier canTrade() {
    if (tradingState == 1)
      require(token.isPresaleClaimed(_msgSender()) || owner() == _msgSender(), 'only presale users');

    if (tradingState == 0) require(owner() == _msgSender(), 'trades are not enabled');

    require(owner() == _msgSender() || token.balanceOf(_msgSender()) != 0, 'should be a MINE holder');

    _;
  }

  function setTradingState(uint8 _tradingState) public onlyOwner {
    require(_tradingState < 3, 'trading state should be 0:only owner, 1:whitelisted, 2:public');
    tradingState = _tradingState;
  }

  function setToken(address _token) public onlyOwner {
    require(_token != address(0), 'invalid token address');
    token = IERC20(_token);
  }

  function rebakePizza(address ref) public canTrade {
    require(initialized, 'not initilized');

    if (ref == msg.sender) {
      ref = address(0);
    }

    if (referrals[msg.sender] == address(0) && referrals[msg.sender] != msg.sender) {
      referrals[msg.sender] = ref;
    }

    uint256 eggsUsed=getMyEggs(msg.sender);
    uint256 newMiners=SafeMath.div(eggsUsed,EGGS_TO_HATCH_1MINERS);
    hatcheryMiners[msg.sender]=SafeMath.add(hatcheryMiners[msg.sender],newMiners);
    claimedEggs[msg.sender]=0;
    lastHatch[msg.sender]=block.timestamp;
    
    //send referral Eggs
    claimedEggs[referrals[msg.sender]] = SafeMath.add(claimedEggs[referrals[msg.sender]], SafeMath.div(eggsUsed, 8));

    //boost market to nerf miners hoarding
    marketEggs = SafeMath.add(marketEggs, SafeMath.div(eggsUsed, 5));
  }

  function eatPizza() public canTrade {
    require(initialized, 'not initilized');
    uint256 hasEggs = getMyEggs(msg.sender);
    uint256 eggsValue = calculateEggsell(hasEggs);
    uint256 fee = devFee(eggsValue);
    claimedEggs[msg.sender] = 0;
    lastHatch[msg.sender] = block.timestamp;
    marketEggs = SafeMath.add(marketEggs, hasEggs);
    recAdd.transfer(fee);
    payable(msg.sender).transfer(SafeMath.sub(eggsValue, fee));
  }

  function eggsRewards(address adr) public view returns (uint256) {
    uint256 hasEggs = getMyEggs(adr);
    uint256 eggValue = calculateEggsell(hasEggs);
    return eggValue;
  }

  function bakePizza(address ref) public payable canTrade {
    require(initialized, 'not initilized');
    uint256 EggsBought = calculateeggsBuy(msg.value, SafeMath.sub(address(this).balance, msg.value));
    EggsBought = SafeMath.sub(EggsBought, devFee(EggsBought));
    uint256 fee = devFee(msg.value);
    recAdd.transfer(fee);
    claimedEggs[msg.sender] = SafeMath.add(claimedEggs[msg.sender], EggsBought);
    rebakePizza(ref);
  }

  function calculateTrade(
    uint256 rt,
    uint256 rs,
    uint256 bs
  ) private view returns (uint256) {
    return
      SafeMath.div(
        SafeMath.mul(PSN, bs),
        SafeMath.add(PSNH, SafeMath.div(SafeMath.add(SafeMath.mul(PSN, rs), SafeMath.mul(PSNH, rt)), rt))
      );
  }

  function calculateEggsell(uint256 Eggs) public view returns (uint256) {
    return calculateTrade(Eggs, marketEggs, address(this).balance);
  }

  function calculateeggsBuy(uint256 eth, uint256 contractBalance) public view returns (uint256) {
    return calculateTrade(eth, contractBalance, marketEggs);
  }

  function calculateeggsBuySimple(uint256 eth) public view returns (uint256) {
    return calculateeggsBuy(eth, address(this).balance);
  }

  function devFee(uint256 amount) private view returns (uint256) {
    return SafeMath.div(SafeMath.mul(amount, devFeeVal), 100);
  }

  function openKitchen() public payable onlyOwner {
    require(marketEggs == 0);
    initialized = true;
    marketEggs = 259200000000;
  }

  function getBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getMyMiners(address adr) public view returns (uint256) {
    return hatcheryMiners[adr];
  }

  function getMyEggs(address adr) public view returns (uint256) {
    return SafeMath.add(claimedEggs[adr], getEggsSinceLastHatch(adr));
  }

  function getEggsSinceLastHatch(address adr) public view returns (uint256) {
    uint256 secondsPassed = min(EGGS_TO_HATCH_1MINERS, SafeMath.sub(block.timestamp, lastHatch[adr]));
    return SafeMath.mul(secondsPassed, hatcheryMiners[adr]);
  }

  function min(uint256 a, uint256 b) private pure returns (uint256) {
    return a < b ? a : b;
  }
}
