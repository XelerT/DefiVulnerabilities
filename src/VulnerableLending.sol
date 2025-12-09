// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract VulnerableLending {
    IERC20 public token;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public borrowed;
    
    constructor(address _token) {
        token = IERC20(_token);
    }
    
    function deposit(uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        deposits[msg.sender] += amount;
    }
    
    function borrow(uint256 amount) external {
        require(amount * 2 <= deposits[msg.sender], "Insufficient collateral");
        borrowed[msg.sender] += amount;
        
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient contract balance");
        
        require(token.transfer(msg.sender, amount), "Transfer failed");
    }
    
    function liquidate(address user) external {
        require(borrowed[user] > 0, "No debt to liquidate");
        uint256 collateral = deposits[user];
        
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance >= collateral, "Insufficient contract balance");
        
        deposits[user] = 0;
        borrowed[user] = 0;
        require(token.transfer(msg.sender, collateral), "Transfer failed");
    }
}