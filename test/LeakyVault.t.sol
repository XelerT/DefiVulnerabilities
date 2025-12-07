// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {LeakyVault} from "../src/LeakyVault.sol";
import {ReentrancyAttacker} from "../src/Attacker.sol";

contract LeakyVaultTest is Test {
    LeakyVault vault;
    ReentrancyAttacker attacker;

    address victim      = address(0x1);
    address attackerEOA = address(0x2);

    function setUp() public {
        vault = new LeakyVault();

        vm.prank(attackerEOA);
        attacker = new ReentrancyAttacker(vault);

        vm.deal(victim, 100 ether);
        vm.deal(attackerEOA, 100 ether);

        vm.prank(victim);
        vault.deposit{value: 10 ether}();
    }

    function test_NormalWithdrawByVictim() public {
        vm.prank(victim);
        vault.withdraw();

        assertEq(victim.balance, 100 ether);
        assertEq(vault.balanceOf(victim), 0);
        assertEq(address(vault).balance, 0);
    }

    function test_ReentrancyAttackDrainsVault() public {
        uint256 vaultBalanceBefore = address(vault).balance;  // 10 ETH
        uint256 attackerEOABefore  = attackerEOA.balance;     // 100 ETH

        // Now msg.sender == owner inside attacker.attack()
        vm.prank(attackerEOA);
        attacker.attack{value: 1 ether}();

        uint256 vaultBalanceAfter = address(vault).balance;
        uint256 attackerEOAAfter  = attackerEOA.balance;

        assertEq(vaultBalanceAfter, 0);
        assertEq(vault.balanceOf(victim), 10 ether);
        assertGt(attackerEOAAfter, attackerEOABefore - 1 ether);

        emit log_named_uint("vaultBalanceBefore", vaultBalanceBefore);
        emit log_named_uint("vaultBalanceAfter", vaultBalanceAfter);
        emit log_named_uint("attackerEOABefore", attackerEOABefore);
        emit log_named_uint("attackerEOAAfter", attackerEOAAfter);
        emit log_named_uint("attackCount", attacker.attackCount());
    }
}
