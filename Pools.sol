// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./MainCoinManager.sol";
//import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Pools is MainCoinManager {
    event NewPool(address token, uint256 id);
    event FinishPool(uint256 id);
    event PoolUpdate(uint256 id);

    constructor() public {
        poolsCount = 0; //Start with 0
    }

    uint256 public poolsCount; // the ids of the pool
    mapping(uint256 => Pool) public pools; //the id of the pool with the data
    uint256[] public metalCoins;
    mapping(address => uint256[]) public poolsMap; //the address and all of the pools id's
    struct Pool {
        address Token; //the address of the erc20 toke for sale
        address Creator; //the project owner
        uint256 FinishTime; //Until what time the pool is active
        uint256 Rate; //for eth Wei, in token, by the decemal. the cost of 1 token
        address Maincoin; // on adress.zero = ETH
        uint256 StartAmount; //The total amount of the tokens for sale
        uint256 Lefttokens; // the ammount of tokens left for sale
        uint256 StartTime; // the time the pool open //TODO Maybe Delete this?
        bool TookLeftOvers; //The Creator took the left overs after the pool finished
        bool isMetal;       //For metal coins(ETHXAU and ETHXAG)
        uint256 MetalPurchaseRate;   //price at which the user will get Maincoin against this token
        bool Is21DecimalRate; //If true, the rate will be rate*10^-21
    }

    function GetLastPoolId() public view returns (uint256) {
        return poolsCount;
    }
    
     //create a new pool
    function CreatePool(
        address _Token, //token to sell address
        uint256 _FinishTime, //Until what time the pool will work
        uint256 _Rate, //the rate of the trade
        uint256 _StartAmount, //Total amount of the tokens to sell in the pool
        address _MainCoin, // address(0x0) = ETH, address of main token
        bool _isMetal,
        uint256 _metalPurchaseRate,
        bool _Is21Decimal //focus the for smaller tokens.
    ) public whenNotPaused onlyOwner {
        require(IsValidToken(_Token), "Need Valid ERC20 Token"); //check if _Token is ERC20
        require(
            _MainCoin == address(0x0) || IsERC20Maincoin(_MainCoin),
            "Main coin not in list"
        );
        require(_FinishTime - now < MaxDuration, "Can't be that long pool");
        require(
            SafeMath.add(now, MinDuration) <= _FinishTime,
            "Need more then MinDuration"
        ); // check if the time is OK
        TransferInToken(_Token, msg.sender, _StartAmount);
        //register the pool
        pools[poolsCount] = Pool(
            _Token,
            msg.sender,
            _FinishTime,
            _Rate,
            _MainCoin,
            _StartAmount,
            _StartAmount,
            now,
            false,
            _isMetal,
            _metalPurchaseRate,
            _Is21Decimal
        );
        poolsMap[msg.sender].push(poolsCount);
        emit NewPool(_Token, poolsCount);
        if(_isMetal){metalCoins.push(poolsCount);}
        poolsCount = SafeMath.add(poolsCount, 1); //joke - overflowfrom 0 on int256 = 1.16E77
    }
}