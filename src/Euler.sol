// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


contract ERC20Mock {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "not allowed");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "insufficient");
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
    }
}

// Euler-like lending pool demonstrating the donateToReserves bug
contract EulerLikeLending {
    ERC20Mock public immutable token;

    mapping(address => uint256) public collateral; // user's deposited tokens
    mapping(address => uint256) public debt;       // user's borrowed tokens

    uint256 public reserves; // protocol reserves, used to pay liquidation bonus

    constructor(ERC20Mock _token) {
        token = _token;
    }

    // User deposits tokens as collateral.
    function deposit(uint256 amount) external {
        require(amount > 0, "zero");
        require(token.transferFrom(msg.sender, address(this), amount), "transfer failed");
        collateral[msg.sender] += amount;
    }

    // User borrows tokens. Simple 50% LTV.
    function borrow(uint256 amount) external {
        require(amount > 0, "zero");
        // require collateral >= 2 * (existing debt + new amount) / 1  => ~50% LTV
        require(
            collateral[msg.sender] * 2 >= debt[msg.sender] + amount,
            "not enough collateral"
        );
        debt[msg.sender] += amount;
        require(token.transfer(msg.sender, amount), "transfer failed");
    }

    // Donate some of your collateral into protocol reserves.
    // VULNERABLE: no health check; can be called when the account is
    //      already close to or below solvency.
    function donateToReserves(uint256 amount) external {
        require(collateral[msg.sender] >= amount, "not enough collateral");
        // NO CHECK: this can push the account into insolvency
        collateral[msg.sender] -= amount;
        reserves += amount;
    }

    // Simple "health factor" = collateral / debt (scaled 1e18).
    function health(address user) public view returns (uint256) {
        if (debt[user] == 0) return type(uint256).max;
        return (collateral[user] * 1e18) / debt[user];
    }

    // Liquidator repays all of `user`'s debt, receives their collateral + bonus from reserves
    // Over-generous bonus from reserves makes the donateToReserves misuse profitable
    function liquidate(address user) external {
        require(health(user) < 1e18, "user still solvent"); // < 1.0

        uint256 userDebt = debt[user];
        uint256 userColl = collateral[user];

        require(userDebt > 0, "no debt");

        // Liquidator repays all debt
        debt[user] = 0;
        collateral[user] = 0;

        require(
            token.transferFrom(msg.sender, address(this), userDebt),
            "repay failed"
        );

        // Liquidation bonus = 50% of debt, capped by reserves
        uint256 bonus = userDebt / 2;
        if (bonus > reserves) {
            bonus = reserves;
        }
        reserves -= bonus;

        // Liquidator gets user's collateral + bonus from reserves
        uint256 payout = userColl + bonus;
        require(token.transfer(msg.sender, payout), "payout failed");
    }
}

/*
How this demonstrates the Euler-style bug:

1. User deposits some collateral and borrows as much as allowed by the LTV rule.
2. User calls donateToReserves() with a big amount, reducing their collateral and pushing
   health(user) < 1.
   - This function DOES NOT check health(user) before allowing the donation.
3. Now the position is under-collateralized; liquidate() can be called.
4. A second address (controlled by the attacker) calls liquidate(user), repays userDebt,
   and receives userColl + bonus from `reserves`.
5. Because reserves were funded using the user's own donated collateral plus any pre-existing
   reserves, and the bonus formula is generous, this can drain protocol reserves.

In real Euler, the math + donateToReserves + self-liquidation + flash loans made this a
large, capital-efficient attack. This toy focuses on the missing "liquidity / health check"
in donateToReserves and over-generous bonus logic.
*/
