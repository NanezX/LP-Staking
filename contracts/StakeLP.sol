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
// WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" == uniswapRouter.WETH()

contract StakeLP is Initializable{
    IUniswapV2Router02 uniswapRouter;
    IUniswapV2Factory uniswapFactory;
    event LiquidityAdded(
        address indexed sender,
        address indexed token, 
        uint amountLPTokens, 
        uint time
    );

    function initialize(address _router, address _factory) public initializer {
        uniswapRouter = IUniswapV2Router02(_router);
        uniswapFactory = IUniswapV2Factory(_factory);
    }


    function permitToken(
        address token,
        address signer,
        uint deadline,
        bytes32 r, 
        bytes32 s, 
        uint8 v
     ) public {
         IUniswapV2ERC20 tokenUniswap = 
            IUniswapV2ERC20(uniswapFactory.getPair(token, uniswapRouter.WETH()));
         tokenUniswap.permit(
             signer, 
             address(this), 
             tokenUniswap.balanceOf(signer), 
            deadline, 
             v, 
             r, 
             s
        );
     }

    function getBalanceLPTokens(address token) public view returns(uint){
        address pair = uniswapFactory.getPair(token, uniswapRouter.WETH());
        IUniswapV2ERC20 tokenUniswap = IUniswapV2ERC20(pair);
        return tokenUniswap.balanceOf(msg.sender);
    }

    function addLiquidityWithETH(address token) public payable {
        require(msg.value  > 0, "ERROR: Has not been sent ETH");
        uint amountETH = msg.value / 2;
        uint amountTokens = _swapETHForTokens(token, amountETH);
        uint lpTokens = _addLiquidity(token, amountTokens, amountETH);
        emit LiquidityAdded(msg.sender, token, lpTokens, block.timestamp);
    }
    
    function _addLiquidity (address token, uint amounToken, uint amountETH) internal returns(uint) {
        IERC20 Itoken = IERC20(token);
        Itoken.approve(address(uniswapRouter), amounToken);

        (, , uint liquidity) = uniswapRouter.addLiquidityETH{value:  amountETH}(
            token, amounToken, 
            (amounToken * 9970) / 10000, // 9970 = 99.7% (0.3% slip)
            (amountETH * 9970) / 10000, 
            msg.sender, 
            block.timestamp + 3600
        );
        return liquidity;
    }

    function stakeLPTokens (
        address token,
        address owner,
        uint value,
        uint deadline,
        uint8 v, 
        bytes32 r, 
        bytes32 s
     ) public payable {
        address pair = uniswapFactory.getPair(token, uniswapRouter.WETH());
        IUniswapV2ERC20 tokenUniswap = IUniswapV2ERC20(pair);
        tokenUniswap.permit(
            owner, 
            address(this), 
            value, 
            block.timestamp + deadline, 
            v, 
            r, 
            s
        );
    }

    function addLiquidityAndStake () public payable {
        
    }

    function _swapETHForTokens (
        address AddressesTokensOut,
        uint amountETH
     ) internal returns(uint){
            address[] memory path = new address[](2); 
            path[0] = uniswapRouter.WETH(); 
            path[1] = AddressesTokensOut;
            uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value:  amountETH}(
                    1,
                    path, 
                    address(this), 
                    block.timestamp + 3600
            ); 
            return amounts[1];
    }
    
    receive() payable external {} // Only receive the leftover ether
}