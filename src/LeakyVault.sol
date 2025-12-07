// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 Victims deposit ETH.

Attacker deposits a little ETH.

During withdraw, the vault sends ETH before it zeroes the balance.

In the attacker’s receive() function, we reenter withdraw() again and again, draining the whole vault.
*/

contract LeakyVault {
    mapping(address => uint256) public balanceOf;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "zero");
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 bal = balanceOf[msg.sender];
        require(bal > 0, "no balance");

        // external call before state update
        (bool ok, ) = msg.sender.call{value: bal}("");
        require(ok, "send failed");

        balanceOf[msg.sender] = 0;

        emit Withdraw(msg.sender, bal);
    }
}
