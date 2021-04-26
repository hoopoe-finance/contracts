// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/access/Ownable.sol";

interface HoFactory{
    function addUserPool(address _user, address  _pool)external returns(bool);
    function removeUserPool(address _user, address  _pool)external returns(bool);
    function poolUpdate(address _poolAddress)external;
}

contract HoFarm is Ownable{
    using SafeMath for uint256;

    mapping (address => uint256) private _stakes;
    mapping (address => uint256) public stakeTimestamp;
    mapping (address => uint256) public userClaimedRewards;

    string public name;
    address  public tokenAddress;
    address  public rewardTokenAddress;
    uint public stakingStarts;
    uint public stakingEnds;
    uint public withdrawStarts;
    uint public withdrawEnds;
    uint256 public stakedTotal;
    uint256 public stakingCap;
    uint256 public totalReward;
    uint256 public earlyWithdrawReward;
    uint256 public rewardBalance;
    uint256 public stakedBalance;
    address hoFactoryAddress;
    bool public isFarm;


    IERC20 public ERC20Interface;
    HoFactory public hoFactoryinterface;
    event Staked(address indexed token, address indexed staker_, uint256 requestedAmount_, uint256 stakedAmount_);
    event PaidOut(address indexed token, address indexed rewardToken, address indexed staker_, uint256 amount_, uint256 reward_);

    /**
     */
    constructor (string memory name_,
        address tokenAddress_,
        address rewardTokenAddress_,
        uint stakingStarts_,
        uint stakingEnds_,
        uint withdrawStarts_,
        uint withdrawEnds_,
        uint256 stakingCap_,
        bool isFarm_,
        address hoFactory_,
        address admin_) public {
        hoFactoryAddress = hoFactory_;
        name = name_;
        require(tokenAddress_ != address(0), "Festaking: 0 address");
        tokenAddress = tokenAddress_;

        require(rewardTokenAddress_ != address(0), "Festaking: 0 reward address");
        rewardTokenAddress = rewardTokenAddress_;

        require(stakingStarts_ > 0, "Festaking: zero staking start time");
        if (stakingStarts_ < now) {
            stakingStarts = now;
        } else {
            stakingStarts = stakingStarts_;
        }

        require(stakingEnds_ > stakingStarts, "Festaking: staking end must be after staking starts");
        stakingEnds = stakingEnds_;

        require(withdrawStarts_ >= stakingEnds, "Festaking: withdrawStarts must be after staking ends");
        withdrawStarts = withdrawStarts_;

        require(withdrawEnds_ > withdrawStarts, "Festaking: withdrawEnds must be after withdraw starts");
        withdrawEnds = withdrawEnds_;

        require(stakingCap_ > 0, "Festaking: stakingCap must be positive");
        stakingCap = stakingCap_;
        
        isFarm = isFarm_;
        transferOwnership(admin_);
    }

    function addReward(uint256 rewardAmount, uint256 withdrawableAmount)
    public
    _before(withdrawStarts)
    returns (bool) {
        require(rewardAmount > 0, "Festaking: reward must be positive");
        require(withdrawableAmount >= 0, "Festaking: withdrawable amount cannot be negative");
        require(withdrawableAmount <= rewardAmount, "Festaking: withdrawable amount must be less than or equal to the reward amount");
        address from = msg.sender;
        if (!_payMe(from, rewardAmount,rewardTokenAddress)) {
            return false;
        }

        totalReward = totalReward.add(rewardAmount);
        rewardBalance = totalReward;
        earlyWithdrawReward = earlyWithdrawReward.add(withdrawableAmount);
        return true;
    }

    function stakeOf(address account) public view returns (uint256) {
        return _stakes[account];
    }

    /**
    * Requirements:
    * - `amount` Amount to be staked
    */
    function stake(uint256 amount)
    public
    _positive(amount)
    _realAddress(msg.sender)
    returns (bool) {
        address from = msg.sender;
        return _stake(from, amount);
    }

    function withdraw(uint256 amount)
    public
    _after(withdrawStarts)
    _positive(amount)
    _realAddress(msg.sender)
    returns (bool) {
        address from = msg.sender;
        require(amount <= _stakes[from], "Festaking: not enough balance");
        if (now < withdrawEnds) {
            return _withdrawEarly(from, amount);
        } else {
            return _withdrawAfterClose(from, amount);
        }
    }

    function _withdrawEarly(address from, uint256 amount)
    private
    _realAddress(from)
    returns (bool) {
        // This is the formula to calculate reward:
        // r = (earlyWithdrawReward / stakedTotal) * (now - stakingEnds) / (withdrawEnds - stakingEnds)
        // w = (1+r) * a
        uint256 denom = (withdrawEnds.sub(stakingEnds)).mul(stakedTotal);
        uint256 reward = (
        ( (now.sub(stakingEnds)).mul(earlyWithdrawReward) ).mul(amount)
        ).div(denom);
        rewardBalance = rewardBalance.sub(reward);
        stakedBalance = stakedBalance.sub(amount);
        _stakes[from] = _stakes[from].sub(amount);
        hoFactoryinterface = HoFactory(hoFactoryAddress);
        if(_stakes[from] == 0){
            hoFactoryinterface.removeUserPool(from, address(this));
        }
        bool principalPaid = _payDirect(from, amount, tokenAddress);
        bool rewardPaid = _payDirect(from, reward, rewardTokenAddress);
        require(principalPaid && rewardPaid, "Festaking: error paying");
        hoFactoryinterface.poolUpdate(address(this));
        emit PaidOut(tokenAddress, rewardTokenAddress, from, amount, reward);
        userClaimedRewards[from] = userClaimedRewards[from].add(reward);
        return true;
    }

    function _withdrawAfterClose(address from, uint256 amount)
    private
    _realAddress(from)
    returns (bool) {
        uint256 reward = (rewardBalance.mul(amount)).div(stakedBalance);
        _stakes[from] = _stakes[from].sub(amount);
        rewardBalance = rewardBalance.sub(reward);
        stakedBalance = stakedBalance.sub(amount);
        hoFactoryinterface = HoFactory(hoFactoryAddress);
        if(_stakes[from] == 0){
            hoFactoryinterface.removeUserPool(from, address(this));
        }
        bool principalPaid = _payDirect(from, amount, tokenAddress);
        bool rewardPaid = _payDirect(from, reward, rewardTokenAddress);
        require(principalPaid && rewardPaid, "Festaking: error paying");
        hoFactoryinterface.poolUpdate(address(this));
        emit PaidOut(tokenAddress, rewardTokenAddress, from, amount, reward);
        userClaimedRewards[from] = userClaimedRewards[from].add(reward);
        return true;
    }

    function _stake(address staker, uint256 amount)
    private
    _after(stakingStarts)
    _before(stakingEnds)
    _positive(amount)
    returns (bool) {
        // check the remaining amount to be staked
        uint256 remaining = amount;
        if (remaining > (stakingCap.sub(stakedBalance))) {
            remaining = stakingCap.sub(stakedBalance);
        }
        // These requires are not necessary, because it will never happen, but won't hurt to double check
        // this is because stakedTotal and stakedBalance are only modified in this method during the staking period
        require(remaining > 0, "Festaking: Staking cap is filled");
        require((remaining + stakedTotal) <= stakingCap, "Festaking: this will increase staking amount pass the cap");
        if (!_payMe(staker, remaining, tokenAddress)) {
            return false;
        }
        emit Staked(tokenAddress, staker, amount, remaining);
        hoFactoryinterface = HoFactory(hoFactoryAddress);
        if(_stakes[staker] == 0){
            hoFactoryinterface.addUserPool(staker, address(this));
        }
        hoFactoryinterface.poolUpdate(address(this));
        // Transfer is completed
        stakedBalance = stakedBalance.add(remaining);
        stakedTotal = stakedTotal.add(remaining);
        _stakes[staker] = _stakes[staker].add(remaining);
        stakeTimestamp[staker] = now;
        return true;
    }

    function _payMe(address payer, uint256 amount, address token)
    private
    returns (bool) {
        return _payTo(payer, address(this), amount, token);
    }

    function _payTo(address allower, address receiver, uint256 amount, address token)
    private
    returns (bool) {
        // Request to transfer amount from the contract to receiver.
        // contract does not own the funds, so the allower must have added allowance to the contract
        // Allower is the original owner.
        ERC20Interface = IERC20(token);
        return ERC20Interface.transferFrom(allower, receiver, amount);
    }

    function _payDirect(address to, uint256 amount, address token)
    private
    returns (bool) {
        if (amount == 0) {
            return true;
        }
        ERC20Interface = IERC20(token);
        return ERC20Interface.transfer(to, amount);
    }
    
    function withdrawUnclaimedRewards() public 
    onlyOwner
    _after(withdrawEnds)
    returns(bool)
    {
        ERC20Interface = ERC20(tokenAddress);
        return ERC20Interface.transfer(owner(), ERC20Interface.balanceOf(address(this)));
    }
    
    function viewUnclaimedUserReward(address _address) public view returns(uint256){
        if (now < withdrawEnds) {
            return viewEarlyRewards(_stakes[_address]);
        } else {
            return viewRewardsAfterClose(_stakes[_address]);
        }
    }
    
    function viewRewardPerAmount(uint256 _amount) public view returns(uint256 amount_, uint256 reward_){
        if (now < withdrawEnds) {
            return (_amount , viewEarlyRewards(_amount));
        } else {
            return (_amount , viewRewardsAfterClose(_amount));
        }
    }
    
    function viewEarlyRewards(uint256 amount) private view returns(uint256){
        // This is the formula to calculate reward:
        // r = (earlyWithdrawReward / stakedTotal) * (now - stakingEnds) / (withdrawEnds - stakingEnds)
        // w = (1+r) * a
        if(now < stakingEnds) return 0;
        uint256 denom = (withdrawEnds.sub(stakingEnds)).mul(stakedTotal);
        if(denom <=0) return 0;
        return (
        ( (now.sub(stakingEnds)).mul(earlyWithdrawReward) ).mul(amount)
        ).div(denom);
    }
    
    function viewRewardsAfterClose(uint256 amount) private view returns(uint256){
        if(stakedBalance == 0) return 0;
        return (rewardBalance.mul(amount)).div(stakedBalance);
        
    }

    modifier _realAddress(address addr) {
        require(addr != address(0), "Festaking: zero address");
        _;
    }

    modifier _positive(uint256 amount) {
        require(amount >= 0, "Festaking: negative amount");
        _;
    }

    modifier _after(uint eventTime) {
        require(now >= eventTime, "Festaking: bad timing for the request");
        _;
    }

    modifier _before(uint eventTime) {
        require(now < eventTime, "Festaking: bad timing for the request");
        _;
    }
    
    function getPoolData()public view returns(
        string memory _name,
        address   _tokenAddress,
        address _rewardTokenAddress,
        uint  _stakingStarts,
        uint  _stakingEnds,
        uint  _withdrawStarts,
        uint  _withdrawEnds,
        uint256  _stakedTotal,
        uint256  _stakingCap,
        uint256  _totalReward,
        uint256  _earlyWithdrawReward,
        uint256  _rewardBalance,
        uint256  _stakedBalance
        ){
        
        return (name,
            tokenAddress,
            rewardTokenAddress,
            stakingStarts,
            stakingEnds,
            withdrawStarts,
            withdrawEnds,
            stakedTotal,
            stakingCap,
            totalReward,
            earlyWithdrawReward,
            rewardBalance,
            stakedBalance);
    }
}