pragma solidity ^0.5.0;

import "./UniswapExchangeInterface.sol";
import "./WETH9Interface.sol";

/**
 * @title Uniswap V1 ETH-WETH Exchange Liquidity Adder
 * @dev Help adding ETH to Uniswap ETH-WETH exchange in one tx.
 * @notice Do not send WETH or UNI token to this contract.
 */
contract UniswapWethLiquidityAdder {
    // Uniswap V1 ETH-WETH Exchange Address
    address public uniswapWethExchangeAddress = 0xA2881A90Bf33F03E7a3f803765Cd2ED5c8928dFb;
    address public wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    WETH9Interface weth = WETH9Interface(wethAddress);
    UniswapExchangeInterface uniswapWethExchange = UniswapExchangeInterface(uniswapWethExchangeAddress);

    constructor() public {
        // approve Uniswap ETH-WETH Exchange to transfer WETH from this contract
        weth.approve(uniswapWethExchangeAddress, 2**256 - 1);
    }

    function () external payable {
        addLiquidity();
    }

    // TODO: should this function return anything?
    /// @dev Receive ETH, add to Uniswap ETH-WETH exchange, and return UNI token.
    /// Will try to add all ETH in this contract to the liquidity pool.
    /// There may be WETH token stuck in this contract?, but we don't care
    function addLiquidity() public payable {
        // If no ETH is received, revert.
        // require(msg.value > 0);

        // Get the amount of ETH now in this contract as the total amount of ETH we are going to add.
        uint256 totalEth = address(this).balance;

        // Get the amount of ETH and WETH in the liquidity pool.
        uint256 ethInPool = uniswapWethExchangeAddress.balance;
        uint256 wethInPool = weth.balanceOf(uniswapWethExchangeAddress);

        // Calculate the amount of WETH we need to wrap.
        // We are solving this:
        //     Find maximum integer `ethToAdd` s.t.
        //     ethToAdd + wethToAdd <= totalEth
        //     wethToAdd = floor(ethToAdd * wethInPool / ethInPool) + 1
        // Solution:
        //     Let x = ethToAdd
        //         A = wethInPool
        //         B = ethInPool
        //         C = totalEth
        //     Then
        //         x + floor(x * A / B) + 1 <= C
        //         <=> x + x * A / B + 1 < C + 1
        //         <=> x + x * A / B < C
        //         <=> x < C * B / (A + B)
        //         <=> max int x = ceil(C * B / (A + B)) - 1
        //     So max `ethToAdd` is ceil(totalEth * ethInPool / (wethInPool + ethInPool)) - 1
        // Notes:
        //     1. In the following code, we set `ethToAdd = floor(C * B / (A + B)) - 1`
        //         instead of `ethToAdd = ceil(C * B / (A + B)) - 1`
        //         because it's cheaper to compute `floor` (just an integer division),
        //         and the difference is at most 1 wei.
        //     2. We don't use SafeMath here because it's almost impossible to overflow
        //         when computing `ethBalance * ethBalance` or `ethBalance * wethBalance`
        uint256 ethToAdd = totalEth * ethInPool / (wethInPool + ethInPool) - 1;
        uint256 wethToAdd = ethToAdd * wethInPool / ethInPool + 1;

        // Wrap ETH.
        weth.deposit.value(wethToAdd)();
        // require(weth.balanceOf(address(this)) == wethToAdd);

        // Add liquidity.
        uint256 liquidityMinted = uniswapWethExchange.addLiquidity.value(ethToAdd)(1, 2**256-1, 2**256-1);
        // require(liquidityMinted > 0);

        // Transfer liquidity token to msg.sender.
        // uint256 liquidityTokenBalance = uniswapWethExchange.balanceOf(msg.sender);
        uniswapWethExchange.transfer(msg.sender, liquidityMinted);
        // require(uniswapWethExchange.transfer(msg.sender, liquidityMinted));
    }
}
