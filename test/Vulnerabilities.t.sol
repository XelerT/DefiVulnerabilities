// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VulnerableToken.sol";
import "../src/VulnerableAuction.sol";
import "../src/VulnerableLending.sol";

contract VulnerabilitiesTest is Test {
    VulnerableToken public token;
    VulnerableAuction public auction;
    VulnerableLending public lending;
    
    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);
    
    function setUp() public {
        vm.startPrank(owner);
        token = new VulnerableToken(1000000 * 10**18);
        auction = new VulnerableAuction(1 days);
        lending = new VulnerableLending(address(token));
        
        token.approve(address(lending), type(uint256).max);
        lending.deposit(100000 * 10**18);
        
        vm.stopPrank();
    }
    
    function testAuctionGasLimit() public {
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        
        vm.deal(bob, 10 ether);
        vm.prank(bob);
        auction.bid{value: 2 ether}();
        
        assertEq(auction.pendingReturns(alice), 1 ether);
    }
    
    function testAuctionTransferFailure() public {
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        vm.warp(block.timestamp + 2 days);
        
        assertEq(address(auction).balance, 1 ether);
    }
    
    function testLendingLiquidation() public {
        vm.prank(owner);
        token.transfer(alice, 1000 * 10**18);
        
        vm.prank(alice);
        token.approve(address(lending), type(uint256).max);
        
        vm.prank(alice);
        lending.deposit(100 * 10**18);
        
        vm.prank(alice);
        lending.borrow(50 * 10**18);
        
        uint256 bobBalanceBefore = token.balances(bob);
        
        vm.prank(bob);
        lending.liquidate(alice);
        
        uint256 bobBalanceAfter = token.balances(bob);
        assertEq(bobBalanceAfter - bobBalanceBefore, 100 * 10**18);
        
        assertEq(lending.deposits(alice), 0);
        assertEq(lending.borrowed(alice), 0);
    }
    
    function testTokenApprovalRace() public {
        vm.prank(owner);
        token.transfer(alice, 1000 * 10**18);
        
        vm.prank(alice);
        token.approve(bob, 5 * 10**18);
        
        assertEq(token.allowances(alice, bob), 5 * 10**18);
    }
    
    function testTokenLockedInContract() public {
        vm.prank(owner);
        token.transfer(alice, 100 * 10**18);
        
        address contractAddr = address(new ContractWithoutWithdraw());
        
        vm.prank(alice);
        token.transfer(contractAddr, 10 * 10**18);
        
        assertEq(token.balances(contractAddr), 10 * 10**18);
    }
}

contract ContractWithoutWithdraw {
}