// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDEX {
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public liquidity;

    event Swapped(address indexed user, uint256 amountIn, uint256 amountOut);

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {
        liquidity[tokenA][tokenB] += amountA;
        liquidity[tokenB][tokenA] += amountB;
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256) {
        uint256 amountOut = calculateOut(tokenIn, tokenOut, amountIn);

        (bool success, ) = tokenOut.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amountOut)
        );
        require(success, "Transfer failed");

        liquidity[tokenIn][tokenOut] += amountIn;
        liquidity[tokenOut][tokenIn] -= amountOut;

        emit Swapped(msg.sender, amountIn, amountOut);
        return amountOut;
    }

    function calculateOut(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
        uint256 reserveIn = liquidity[tokenIn][tokenOut];
        uint256 reserveOut = liquidity[tokenOut][tokenIn];
        return (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    function flashLoan(address token, uint256 amount) external {
        (bool success, ) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount)
        );
        require(success, "Flash loan failed");

        (bool callbackSuccess, ) = msg.sender.call(
            abi.encodeWithSignature("executeOperation(address,uint256)", token, amount)
        );
        require(callbackSuccess, "Callback failed");

        (bool returnSuccess, ) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount)
        );
        require(returnSuccess, "Repayment failed");
    }
}
