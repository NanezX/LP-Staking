// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";

import "./interfaces/IERC20.sol";

import "hardhat/console.sol";

// Factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
// WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

contract StakeLP is Initializable{
    IUniswapV2Router02 uniswapRouter;
    event AddedLiquidity(address indexed sender, uint liquidityTokens);

    function initialize(address _router) public initializer {
        uniswapRouter = IUniswapV2Router02(_router);
    }

    function addLiquidityWithETH(address token) public payable {
        require(msg.value  > 0, "ERROR: Has not been sent ETH");
        uint amountETH = msg.value / 2;
        uint amount = _swapETHForTokens(token, amountETH);
        uint lpTokens = _addLiquidity(token, amount, amountETH);
    }
    
    function _addLiquidity (address token, uint amounToken, uint amountETH) internal returns(uint) {
        IERC20 Itoken = IERC20(token);
        Itoken.approve(address(uniswapRouter), amounToken);

        (, , uint liquidity) = uniswapRouter.addLiquidityETH{value:  amountETH}(
            token, amounToken, 
            (amounToken * 9070) / 10000, // 0.3% slip
            (amountETH * 9070) / 10000, 
            msg.sender, 
            block.timestamp + 3600
        );
        return liquidity;
    }

    function stakeLPTokens (address token) public payable {
        require(msg.value > 0, "Has been not send any ether");

    }

    function addLiquidityAndStake () public payable {
        
    }


    function _swapETHForTokens (
        address AddressesTokensOut, // Token addresses that are requested 
        uint amountETH
    ) internal returns(uint){

            // IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

            // Create the path between weth (ether) and the token
            address[] memory path = new address[](2); 
            path[0] = uniswapRouter.WETH(); 
            path[1] = AddressesTokensOut;

            // make the exchange
            uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value:  amountETH}(
                    1,
                    path, 
                    address(this), 
                    block.timestamp + 3600
            ); 
            return amounts[1];
            
            // recipient.call{value: fee}(""); // transfer fee to my recipient 
            // msg.sender.call{ value: address(this).balance }(""); // refund the rest of ether
    }
//     uniswapRouter.swapETHForExactTokens{value:  amountETH}(
//         1000000000000000000,
//         path,
//         msg.sender,
//         block.timestamp + 3600
//     );
// function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
//   external
//   payable
//   returns (uint[] memory amounts);
    
    receive() payable external {} // Only receive the leftover ether
}