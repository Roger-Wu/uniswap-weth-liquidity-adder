pragma solidity ^0.5.0;

import "./UniswapExchangeInterface.sol";
import "./WETH9Interface.sol";

/**
 * @title Uniswap ETH-WETH Exchange Liquidity Adder
 * @author Roger Wu (@Roger-Wu)
 * @dev Help add ETH to Uniswap's ETH-WETH exchange in one transaction.
 * @notice Do not send WETH or UNI token to this contract.
 */
contract UniswapWethLiquidityAdder {
    // Uniswap V1 ETH-WETH Exchange Address
    address public uniswapWethExchangeAddress = 0xA2881A90Bf33F03E7a3f803765Cd2ED5c8928dFb;
    address public wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    WETH9Interface weth = WETH9Interface(wethAddress);
    UniswapExchangeInterface uniswapWethExchange = UniswapExchangeInterface(uniswapWethExchangeAddress);

    constructor() public {
        // approve the exchange to transfer WETH from this contract
        weth.approve(uniswapWethExchangeAddress, 2**256-1);
    }

    function () external payable {
        addLiquidity();
    }

    /// @dev This function will
    /// 1. receive ETH,
    /// 2. fetch the price of WETH/ETH from Uniswap's ETH-WETH exchange,
    /// 3. wrap part of the ETH to WETH (the amount is dependent on the price),
    /// 4. add ETH and WETH to the exchange and get liquidity tokens,
    /// 5. transfer the liquidity tokens to msg.sender.
    /// notice: There may be a few weis stuck in this contract.
    function addLiquidity() public payable returns (uint256 liquidity) {
        // If no ETH is received, do nothing.
        if (msg.value == 0) {
            return 0;
        }

        // Get the amount of ETH now in this contract.
        uint256 totalEth = address(this).balance;

        // Get the amount of ETH and WETH in the liquidity pool.
        uint256 ethInPool = uniswapWethExchangeAddress.balance;
        uint256 wethInPool = weth.balanceOf(uniswapWethExchangeAddress);
        uint256 sumEthWethInPool = ethInPool + wethInPool; // should never overflow

        // Compute the amount of ETH and WETH we will add to the pool.
        uint256 ethToAdd;
        uint256 wethToAdd;
        if (sumEthWethInPool == 0) {
            // If no liquidity in the exchange, set ethToAdd:wethToAdd = 1:1.
            wethToAdd = totalEth / 2;
            ethToAdd = totalEth - wethToAdd;
        } else {
            // If there's liquidity in the exchange, set ethToAdd:wethToAdd = ethInPool:wethInPool.

            // Problem:
            //     What's the maximum value of ETH and WETH we can add to the pool?
            // Notice:
            //     In the following comments, '/' stands for a normal division, not an integer division.
            // Solution:
            //     Let `ethToAdd` be the amount of weis we are adding to the pool.
            //     Then we are actually solving this:
            //         Find maximum non-negative integer `ethToAdd` s.t.
            //         ethToAdd + wethToAdd <= totalEth
            //         wethToAdd = floor(ethToAdd * wethInPool / ethInPool) + 1    (from Uniswap's contract)
            //     Let x = ethToAdd
            //         A = wethInPool
            //         B = ethInPool
            //         C = totalEth
            //     Then
            //            x + floor(x * A / B) + 1 <= C
            //         => floor(x * A / B) <= C - x - 1
            //         => x * A / B < C - x - 1 + 1
            //         => x + x * A / B < C
            //         => x < C * B / (A + B)
            //         => max int x = ceil(C * B / (A + B)) - 1
            //     So max ethToAdd = ceil(totalEth * ethInPool / (wethInPool + ethInPool)) - 1
            // Notes:
            //     1. ceil(a / b) = floor((a + b - 1) / b) if a, b are integers.
            //     2. We don't use SafeMath here because it's almost impossible to overflow
            //        when computing `ethBalance * ethBalance` and `ethBalance * wethBalance`
            //        because the amount of ETH and WETH should be much less than 2**128.
            //        It saves some gas not using SafeMath.
            ethToAdd = (totalEth * ethInPool + sumEthWethInPool - 1) / sumEthWethInPool - 1;
            wethToAdd = ethToAdd * wethInPool / ethInPool + 1;
        }

        // Wrap ETH.
        weth.deposit.value(wethToAdd)();

        // Add liquidity to ETH-WETH pool.
        uint256 liquidityMinted = uniswapWethExchange.addLiquidity.value(ethToAdd)(1, 2**256-1, 2**256-1);

        // Transfer liquidity token to msg.sender.
        require(uniswapWethExchange.transfer(msg.sender, liquidityMinted));

        return liquidityMinted;
    }
}
