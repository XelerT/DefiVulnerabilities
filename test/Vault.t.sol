// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

contract VaultTest is Test {
    Vault v;
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    function setUp() public {
        v = new Vault();
        // give test users ETH on the local EVM
        vm.deal(alice, 100 ether);
        vm.deal(bob,   100 ether);
    }

    function test_DepositAndWithdraw() public {
        // act as alice
        vm.prank(alice);
        v.deposit{value: 2 ether}();

        assertEq(v.balanceOf(alice), 2 ether);

        // withdraw 1 ETH
        vm.prank(alice);
        v.withdraw(1 ether);

        assertEq(v.balanceOf(alice), 1 ether);
        assertEq(alice.balance, 99 ether); // started with 100
    }
}

