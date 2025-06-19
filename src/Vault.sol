// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // 1. Pass the token address to the constructor
    // 2. Create a deposit function that mints token to the user equivalent to the ETH sent by the user
    // 3. Create a redeem function that burns the user's token and sends the user ETH
    IRebaseToken private immutable i_rebaseToken;

    event Deposit(uint256 amount, address indexed sender);
    event Redeem(uint256 amount, address indexed redeemer);

    error Vault__RedeemFailed();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {

    }

    /** 
    * @notice Allows users to deposit ETH and mint Rebase Tokens
    */
    function deposit() external payable  {
        // Use the amount of ETH sent to mint token to the user
        uint256 received = msg.value;
        i_rebaseToken.mint(msg.sender, received);
        emit Deposit(received, msg.sender);

    }

    /** 
    * @notice Allows users to redeem ETH and burn the equivalent Rebase Token in the process
    * @param _amount The amount of Rebase Token to redeem
    */
    function redeem(uint256 _amount) external payable {
        if(_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // Send back ETH to the user and then burn the tokens
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if(!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(_amount, msg.sender);
    }

    function getRebaseTokenAddress() external view returns(address) {
        return address(i_rebaseToken);
    }
}
