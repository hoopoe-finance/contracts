s// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./PoolsData.sol";
//import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Depeq is PoolsData {
    event NewInvestorEvent(uint256 Investor_ID, address Investor_Address);

    modifier CheckFinishTime(uint256 _Time) {
        require(now <= _Time, "Pool closed, Time exceded");
        _;
    }
    
    modifier onlyOracle(){
        require(msg.sender == oracle);
        _;
    }
    
    address public oracle;

    //using SafeMath for uint256;
    constructor(address _oracle) public {
        oracle = _oracle;
        TotalInvestors = 0;
    }

    //Investorsr Data
    uint256 internal TotalInvestors;
    mapping(uint256 => Investor) Investors;
    mapping(address => uint256[]) InvestorsMap;
    struct Investor {
        uint256 Poolid; //the id of the pool, he got the rate info and the token, check if looked pool
        address InvestorAddress; //
        uint256 MainCoin; //the amount of the main coin invested (eth/dai), calc with rate
        uint256 TokensOwn; //the amount of Tokens the investor needto get from the contract
        uint256 InvestTime; //the time that investment made
    }

    //@dev Send in wei
    function InvestETH(uint256 _PoolId)
        external
        payable
        ReceivETH(msg.value, msg.sender,MinETHInvest)
        whenNotPaused
        CheckFinishTime(pools[_PoolId].FinishTime)
    {
        require(_PoolId < poolsCount, "Wrong pool id, InvestETH fail");
        require(pools[_PoolId].Maincoin == address(0x0), "Pool is not for ETH");
        require(msg.value >= MinETHInvest && msg.value <= MaxETHInvest, "Investment amount not valid");
        require(msg.sender == tx.origin && !isContract(msg.sender), "Some thing wrong with the msgSender");
        NewInvestor(msg.sender, msg.value, _PoolId);
        uint256 Tokens = CalcTokens(_PoolId, msg.value);
        TransferToken(pools[_PoolId].Token, msg.sender, Tokens);
        TransferETH(pools[_PoolId].Creator, msg.value); // send money to project owner
        RegisterInvest(_PoolId, Tokens);
    }

    function InvestERC20(uint256 _PoolId, uint256 _Amount)
        external
        whenNotPaused
        CheckFinishTime(pools[_PoolId].FinishTime)
    {
        require(_PoolId < poolsCount, "Wrong pool id, InvestERC20 fail");
        require(
            pools[_PoolId].Maincoin != address(0x0),
            "Pool is for ETH, use InvetETH"
        );
        require(_Amount > 10000, "Need invest more then 10000");
        require(msg.sender == tx.origin && !isContract(msg.sender), "Caller must not be a contract");
        TransferInToken(pools[_PoolId].Maincoin, msg.sender, _Amount);
        NewInvestor(msg.sender, _Amount, _PoolId);
        uint256 Tokens = CalcTokens(_PoolId, _Amount);
        TransferToken(pools[_PoolId].Token, msg.sender, Tokens);
        TransferToken(
            pools[_PoolId].Maincoin,
            pools[_PoolId].Creator,
            _Amount
        ); // send money to project owner 
        RegisterInvest(_PoolId, Tokens);
    }

    function purchaseMetalERC20(uint256 _PoolId, uint256 _Amount)
    external
    whenNotPaused
    {
        require(_PoolId < poolsCount, "Wrong pool id, InvestERC20 fail");
        require(
            pools[_PoolId].Maincoin != address(0x0),
            "Pool is for ETH, use InvetETH"
        );
        require(pools[_PoolId].isMetal,"not a metal coin");
        require(msg.sender == tx.origin && !isContract(msg.sender), "Caller must not be a contract");
        TransferInToken(pools[_PoolId].Token, msg.sender, _Amount); //recieve tokens from user
        uint256 Tokens = CalcPurchaseValue(_PoolId, _Amount);       //calculate return tokens
        TransferToken(pools[_PoolId].Maincoin, msg.sender, Tokens); //transfering return tokens to user
        TransferToken(
            pools[_PoolId].Token,
            pools[_PoolId].Creator,
            _Amount
        );                                                          // send money to project owner 
        RegisterInvest(_PoolId, Tokens);
    }
    
    function purchaseMetalETH(uint256 _PoolId, uint256 _Amount) external
    whenNotPaused
    whenPurchaseMetalETHOn
    {
        require(_PoolId < poolsCount, "Wrong pool id");
        require(pools[_PoolId].isMetal,"pool is not metal coin");
        require(msg.sender == tx.origin && !isContract(msg.sender), "Some thing wrong with the msgSender");
        uint256 ETH = CalcPurchaseValue(_PoolId, _Amount);              //calculate eth for return
        TransferInToken(pools[_PoolId].Maincoin, msg.sender, _Amount);  //recieving metal tokens from user
        TransferETH(msg.sender, ETH); // send money to seller           //transfering return eth to user
    }

    function RegisterInvest(uint256 _PoolId, uint256 _Tokens) internal {
        require(
            _Tokens <= pools[_PoolId].Lefttokens,
            "Not enough tokens in the pool"
        );
        pools[_PoolId].Lefttokens = SafeMath.sub(
            pools[_PoolId].Lefttokens,
            _Tokens
        );
        if (pools[_PoolId].Lefttokens == 0) emit FinishPool(_PoolId);
        else emit PoolUpdate(_PoolId);
    }

    function NewInvestor(
        address _Sender,
        uint256 _Amount,
        uint256 _Pid
    ) internal returns (uint256) {
        Investors[TotalInvestors] = Investor(
            _Pid,
            _Sender,
            _Amount,
            0,
            block.timestamp
        );
        InvestorsMap[msg.sender].push(TotalInvestors);
        emit NewInvestorEvent(TotalInvestors,_Sender);
        TotalInvestors = SafeMath.add(TotalInvestors, 1);
        return SafeMath.sub(TotalInvestors, 1);
    }
    
    function CalcPurchaseValue(
        uint256 _Pid,
        uint256 _Amount
    )internal view returns (uint256){
        uint256 msgValue = _Amount;
        uint256 result = 0;
        result = SafeMath.mul(msgValue, pools[_Pid].MetalPurchaseRate);
        if (result > 10**21) {
            if (pools[_Pid].Is21DecimalRate) {
                result = SafeMath.div(result, 10**21);
            }
        }
        return SafeMath.div(result,10**18);
    }
        
    
    function CalcTokens(
        uint256 _Pid,
        uint256 _Amount
    ) internal view returns (uint256) {
        uint256 msgValue = _Amount;
        uint256 result = 0;
        result = SafeMath.mul(msgValue, pools[_Pid].Rate);
        if (result > 10**21) {
            if (pools[_Pid].Is21DecimalRate) {
                result = SafeMath.div(result, 10**21);
            }
        }
        return SafeMath.div(result,10**18);
    }
    
        //@dev use it with  require(msg.sender == tx.origin)
    function isContract(address _addr) internal view returns (bool) {      
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
    
    function updateMetalRate(uint256 _PoolId, uint256 _PurchaseRate, uint256 _SaleRate) public onlyOracle returns(bool){
        require(_PoolId < poolsCount, "Wrong pool id");
        require(pools[_PoolId].isMetal,"pool is not metal coin");
        pools[_PoolId].MetalPurchaseRate = _PurchaseRate;
        pools[_PoolId].Rate = _SaleRate;
        return true;
    }
    
    function changeManager(address _newManager) public onlyOwner returns(bool){
        oracle = _newManager;
    }
    
    function getMetalCoinIds() public view returns(uint256[] memory){
        return metalCoins;
    }
    
    //Give all the id's of the investment  by sender address
    function GetMyInvestmentIds() public view returns (uint256[] memory) {
        return InvestorsMap[msg.sender];
    }

    function GetInvestmentData(uint256 _id)
        public
        view
        returns (
            uint256,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        require(
            Investors[_id].InvestorAddress == msg.sender || msg.sender == owner(),
            "Only for the investor (or Admin)"
        );
        return (
            Investors[_id].Poolid,
            Investors[_id].InvestorAddress,
            Investors[_id].MainCoin,
            Investors[_id].TokensOwn,
            Investors[_id].InvestTime
        );
    }
}