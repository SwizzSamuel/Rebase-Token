// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IRebaseToken {
    function mint(address _to, uint256 _amount, uint256 _interestRate) external;
    function burn(address _from, uint256 _amount) external;
    function balanceOf(address _user) external view returns(uint256);
    function getUserRate(address _user) external view returns(uint256);
    function getInterestRate() external view returns(uint256);
}