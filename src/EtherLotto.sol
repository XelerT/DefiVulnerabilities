// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EtherLotto {
    uint constant TICKET_AMOUNT = 10 ether;
    uint constant FEE_AMOUNT = 1 ether;
    address public bank;
    uint public pot;

    constructor() {
        bank = msg.sender;
    }

    function play() payable public {
        require(msg.value == TICKET_AMOUNT, "Must send 10 ether");
        pot += msg.value;

        uint random = uint(keccak256(abi.encodePacked(block.timestamp))) % 2;

        if (random == 0) {
            payable(bank).transfer(FEE_AMOUNT);
            payable(msg.sender).transfer(pot - FEE_AMOUNT);
            pot = 0;
        }
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    receive() external payable {
        pot += msg.value;
    }
}
