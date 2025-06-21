// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/** 
* @title RebaseToken
* @author Samuel Okafor
* @notice This is a crosschain rebase token that incentivises users to deposit into a vault and gain interest
* @notice The interest rate can only decrease
* @notice Each user will have their own interest rate that is the global interest rate of the protocol
*/

contract RebaseToken is ERC20, Ownable, AccessControl {

    error RebaseToken_InterestRateCanOnlyBeDecreased(uint256);
    event NewInterestRate(uint256 newInterestRate);

    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    uint256 private constant PRECISION_FACTOR = 1e18; 
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    constructor() ERC20 ("Rebase Token", "RBT") Ownable(msg.sender) {

    }

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    function setInterestRate(uint256 _newInterestRate) public onlyOwner {
        if(_newInterestRate > s_interestRate) {
            revert RebaseToken_InterestRateCanOnlyBeDecreased(_newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit NewInterestRate(_newInterestRate);
    }

    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
    * @notice Burn the user tokens when they withdraw from the vault
    * @param _from The user to burn the tokens from
    * @param _amount The amount of tokens to burn
    */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        // mitigating against dust in DeFI
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    function balanceOf(address _user) public view override returns(uint256) {
        // get the current number of tokens that have been minted to the user 
        // multiply the priciple balance by the interest rate to get the total balance
        return super.balanceOf(_user) * _calculatedUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;

    }

    /** 
    * @notice Transfer tokens from one user to another
    * @param _recipient The address to receive the transferred tokens
    * @param _amount Amount of tokens to transfer                                                                                                                         
    */
    function transfer(address _recipient, uint256 _amount) public override returns(bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_recipient);
        }
        if(balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /** 
    * @notice Transfer tokens from a user to another
    * @param _sender User to transfer tokens from
    * @param _recipient User to receive transfered tokens
    * @param _amount Amount of tokens to transfer
    */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns(bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_recipient);
        }
        if(balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function _calculatedUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns(uint256 linearInterest) {
        // we need to calculate the interest tthat has accumulated since the last update
        // rhis is going to be a linear growth with time
        // 1. calculate the time since last update
        // 2. calculate the amount of linear growth
        // principal amount + (principal amount * interest rate * time during concerned duration)
        // deposit token = 10
        // interest rate = 0.5
        // time elapsed = 2 seconds
        // 10 + (10 * 0.5 * 2)

        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
    * @notice Mint the accrued interest to the user since the last time they interacted with the protocol
    * @param _user The user to mint the token to
    */
    function _mintAccruedInterest(address _user) internal {
        // find the current balance of rebase token minted to the user -> i.e The principal balance
        uint256 principalBalance = super.balanceOf(_user);
        // calculate their current balance including any interest -> i.e The total balance
        uint256 userBalance = balanceOf(_user);
        // calculate the number of token that needs to be minted to the user (2) - (1)
        uint256 balanceIncrease = userBalance - principalBalance;
        // call _mint to mint tokens to user
        // set the users last updated timestamp to now
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }

    function getUserRate(address _user) external view returns(uint256) {
        return s_userInterestRate[_user];
    }

    /** 
    * @notice Get the interest rate set for the contract. Any new depositor will work with this interest rate
    * @return InterestRate The interest rate stored in the contract
    */
    function getInterestRate() external view returns(uint256) {
        return s_interestRate;
    }

    /** 
    * @notice Get the principle balance of the user. This is the total amount of tokens minted to the user
    * @param _user The user whose principle balance is derived
    * @return Balance The principle balance of the user
    */
    function principleBalanceOf(address _user) external view returns(uint256) {
        return super.balanceOf(_user);
    }

}             