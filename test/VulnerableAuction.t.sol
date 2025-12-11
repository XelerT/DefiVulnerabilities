// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VulnerableAuction.sol";

contract VulnerableAuctionTest is Test {
    VulnerableAuction public auction;
    
    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        auction = new VulnerableAuction(1 days);
        vm.stopPrank();
    }

    function testAuctionTransferFailure() public {
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        vm.warp(block.timestamp + 2 days);

        assertEq(address(auction).balance, 1 ether);
    }
}