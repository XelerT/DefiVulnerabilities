// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VulnerableToken.sol";
import "../src/VulnerableLending.sol";

contract VulnerableLendingTest is Test {
    VulnerableToken public token;
    VulnerableLending public lending;

    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        token = new VulnerableToken(1000000 * 10**18);
        lending = new VulnerableLending(address(token));

        token.approve(address(lending), type(uint256).max);
        lending.deposit(100000 * 10**18);

        vm.stopPrank();
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
}