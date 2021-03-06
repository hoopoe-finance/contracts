// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./ERC20Helper.sol";
//import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract ETHHelper is ERC20Helper {
    constructor() public {
        IsPayble = false;
    }

    modifier ReceivETH(uint256 msgValue, address msgSender, uint256 _MinETHInvest) {
        require(msgValue >= _MinETHInvest, "Send ETH to invest");
        emit TransferInETH(msgValue, msgSender);
        _;
    }

    //@dev not/allow contract to receive funds
    fallback() external payable {
        if (!IsPayble) revert();
    }
    
    receive() external payable{
        if (!IsPayble) revert();
    }

    event TransferOutETH(uint256 Amount, address To);
    event TransferInETH(uint256 Amount, address From);

    bool internal IsPayble;
 
    function GetIsPayble() public view returns (bool) {
        return IsPayble;
    }

    function SwitchIsPayble() public onlyOwner {
        IsPayble = !IsPayble;
    }

    function TransferETH(address _Reciver, uint256 _ammount) internal {
        emit TransferOutETH(_ammount, _Reciver);
        uint256 beforeBalance = address(_Reciver).balance;
        address(uint160(_Reciver)).transfer(_ammount);
        require(
            SafeMath.add(beforeBalance, _ammount) == address(_Reciver).balance,
            "The transfer did not complite"
        );
    }
 
}