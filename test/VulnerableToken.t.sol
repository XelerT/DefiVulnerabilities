// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VulnerableToken.sol";

contract VulnerableTokenTest is Test {
    VulnerableToken public token;
    
    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        token = new VulnerableToken(1000000 * 10**18);
        vm.stopPrank();
    }

    function testTokenApprovalRace() public {
        vm.prank(owner);
        token.transfer(alice, 1000 * 10**18);

        // Alice approves Bob for 100 tokens
        vm.prank(alice);
        token.approve(bob, 100 * 10**18);

        // Bob sees the transaction in the mempool and front-runs it
        // by spending the full 100 tokens immediately
        vm.prank(bob);
        token.transferFrom(alice, bob, 100 * 10**18);

        // Alice then tries to reduce the approval to 50 tokens
        // but Bob has already spent the original 100 tokens
        vm.prank(alice);
        token.approve(bob, 50 * 10**18);

        // Now Bob can spend another 50 tokens (total 150 instead of intended 100)
        vm.prank(bob);
        token.transferFrom(alice, bob, 50 * 10**18);

        // Bob has spent 150 tokens total, more than Alice intended
        assertEq(token.balanceOf(bob), 150 * 10**18);
    }
}