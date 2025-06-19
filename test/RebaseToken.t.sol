// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebasetoken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebasetoken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebasetoken)));
        rebasetoken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testLinearIncrease(uint256 amount) public {
        // vm.assume(amount > 1e5);
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        // deposit
        vault.deposit{value: amount}();
        uint256 startingBalance = rebasetoken.balanceOf(user);
        console.log("Starting Balance:", startingBalance);
        assertEq(startingBalance, amount);

        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebasetoken.balanceOf(user);
        assertGt(middleBalance, startingBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 finalBalance = rebasetoken.balanceOf(user);
        assertGt(finalBalance, middleBalance);

        assertApproxEqAbs(finalBalance - middleBalance, middleBalance - startingBalance, 1);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();
        assertEq(rebasetoken.balanceOf(user), amount);

        vault.redeem(type(uint256).max);
        assertEq(rebasetoken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);

        vm.stopPrank();
        
    }

    function testRedeemAfterTimehasPassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint32).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebasetoken.balanceOf(user);

        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardToVault(balanceAfterSomeTime - depositAmount);

        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user).balance;
        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositAmount);
    } 

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebasetoken.balanceOf(user);
        uint256 user2Balance = rebasetoken.balanceOf(user2);
        
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        //owner reduces interest rate
        vm.prank(owner);
        rebasetoken.setInterestRate(4e10);

        vm.prank(user);
        rebasetoken.transfer(user2, amountToSend);

        uint256 userBalanceAfterTransfer = rebasetoken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebasetoken.balanceOf(user2);
        assertEq(amountToSend, user2BalanceAfterTransfer);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);

        // Check user interest rate has been inherited
        assertEq(rebasetoken.getUserRate(user), 5e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebasetoken.setInterestRate(newInterestRate);
    }

    function testCannotMintAndBurn() public {
        vm.prank(user);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebasetoken.mint(user, 1);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebasetoken.burn(user, 1);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);

        vault.deposit{value: amount}();
        assertEq(rebasetoken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebasetoken.principleBalanceOf(user), amount);
    }

    function testgetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebasetoken));
    }

    function testCanOnlyDecreaseInterestRate(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, rebasetoken.getInterestRate() + 1, type(uint96).max);

        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken_InterestRateCanOnlyBeDecreased.selector);
        rebasetoken.setInterestRate(newInterestRate);
    }
}