// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC20/ERC20.sol";
import "Hoopoe/HoStake.sol";
import "Hoopoe/HoFarm.sol";

contract HoopoeFactory is Ownable{
    
    mapping(uint256 => address) public idToStakingPool;
    mapping(address => uint256) public stakingPoolToId;
    mapping(uint256 => address) public idToFarmingPool;
    mapping(address => uint256) public farmingPoolToId;
    mapping(address => address[]) public myPools;
    uint256 public currStakingPoolId;
    uint256 public currFarmingPoolId;
    
    event PoolUpdated(address);
    
    constructor() public{
        
    }
    
    function createStakingPool(string memory name_,
        address tokenAddress_,
        uint stakingStarts_,
        uint stakingEnds_,
        uint withdrawStarts_,
        uint withdrawEnds_,
        uint256 stakingCap_,
        bool isFarm_) public
        onlyOwner
        returns(address)
        {
            require(isContract(tokenAddress_));
            currStakingPoolId++;
            address newPool = address(new HoStake( name_,
                                          tokenAddress_,
                                          stakingStarts_,
                                          stakingEnds_,
                                          withdrawStarts_,
                                          withdrawEnds_,
                                          stakingCap_,
                                          isFarm_,
                                          address(this),
                                          msg.sender));
            idToStakingPool[currStakingPoolId] = newPool;
            stakingPoolToId[newPool] = currStakingPoolId;
    }
    
    function createFarmPool(string memory name_,
        address tokenAddress_,
        address rewardTokenAddress_,
        uint stakingStarts_,
        uint stakingEnds_,
        uint withdrawStarts_,
        uint withdrawEnds_,
        uint256 stakingCap_,
        bool isFarm_) public 
        onlyOwner 
        returns(address){
            require(isContract(tokenAddress_));
            require(isContract(rewardTokenAddress_));
            currFarmingPoolId++;
            address newPool = address(new HoFarm(name_,
                                            tokenAddress_,
                                            rewardTokenAddress_,
                                            stakingStarts_ ,
                                            stakingEnds_,
                                            withdrawStarts_,
                                            withdrawEnds_,
                                            stakingCap_,
                                            isFarm_,
                                            address(this),
                                            msg.sender));
            idToFarmingPool[currFarmingPoolId] = newPool;
            farmingPoolToId[newPool] = currFarmingPoolId;
    }
    
        //@dev use it with  require(msg.sender == tx.origin)
    function isContract(address _addr) internal view returns (bool) {      
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
    
    function addUserPool(address _user, address  _pool)
    external
    onlyChildContract()
    returns(bool){
        myPools[_user].push(_pool);
    }
    
    function removeUserPool(address _user, address  _pool)
    external
    onlyChildContract()
    returns(bool){
        delete myPools[_user][indexOf(_user,_pool)];
    }
    
    function getMyPools()public view returns(address[] memory){
        return myPools[msg.sender];
    }
    
    modifier onlyChildContract(){
        require(stakingPoolToId[msg.sender] > 0 || farmingPoolToId[msg.sender] > 0);
        _;
    }
    
    function indexOf(address _user, address _pool)internal view returns(uint8){
        for(uint8 i = 0; i<= myPools[_user].length; i++){
            if(myPools[_user][i] == _pool){
                return i;
            }
        }
    }
    
    function getAllPools()public view returns(address[] memory, address[] memory){
        address[] memory ret = new address[](currStakingPoolId);
        address[] memory ret1 = new address[](currFarmingPoolId);
        for (uint i = 1; i <= currStakingPoolId; i++) {
            ret[i-1] = idToStakingPool[i];
        }
        for (uint i = 1; i <= currFarmingPoolId; i++) {
            ret1[i-1] = idToFarmingPool[i];
        }
        return (ret,ret1);
    }
    
    function poolUpdate(address _poolAddress)external onlyChildContract{
        emit PoolUpdated(_poolAddress);
    }
    
}