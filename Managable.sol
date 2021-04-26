// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./ETHHelper.sol";

contract Manageable is ETHHelper {
    constructor() public {
        //Fee = 20; // *10000
        MinDuration = 0; //need to set
        //PoolPrice = 0; // Price for create a pool
        MaxDuration = 60 * 60 * 24 * 30 * 6; // half year
        MinETHInvest = 10000; // for percent calc
        MaxETHInvest = 100 * 10**18; // 100 eth per wallet
    }

    uint256 internal MinDuration; //the minimum duration of a pool, in seconds
    uint256 internal MaxDuration; //the maximum duration of a pool from the creation, in seconds
    uint256 internal PoolPrice;
    uint256 internal MinETHInvest;
    uint256 internal MaxETHInvest;
    bool    internal purchaseMetalETHSwitch = true;
    
    function switchPurchaseMetalETH()public onlyOwner returns(bool){
        purchaseMetalETHSwitch = !(purchaseMetalETHSwitch);
        return true;
    }
    
    modifier whenPurchaseMetalETHOn(){
        require(purchaseMetalETHSwitch, "purchasing metal using eth currently paused by admin");
        _;
    }

    function SetMinMaxETHInvest(uint256 _MinETHInvest, uint256 _MaxETHInvest)
        public
        onlyOwner
    {
        MinETHInvest = _MinETHInvest;
        MaxETHInvest = _MaxETHInvest;
    }
    function GetMinMaxETHInvest() public view returns (uint256 _MinETHInvest, uint256 _MaxETHInvest)
    {
       return (MinETHInvest,MaxETHInvest);
    }

    function GetMinMaxDuration() public view returns (uint256, uint256) {
        return (MinDuration, MaxDuration);
    }

    function SetMinMaxDuration(uint256 _minDuration, uint256 _maxDuration)
        public
        onlyOwner
    {
        MinDuration = _minDuration;
        MaxDuration = _maxDuration;
    }
}