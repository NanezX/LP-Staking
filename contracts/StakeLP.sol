// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";

import "./StakeToken.sol";

import "./interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "hardhat/console.sol";

// Factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
// WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" == uniswapRouter.WETH()

contract StakeLP is Initializable, StakeToken{
    IUniswapV2Router02 uniswapRouter;
    IUniswapV2Factory uniswapFactory;
    event LiquidityAdded(
        address indexed sender,
        address indexed token, 
        uint amountLPTokens, 
        uint time
    );
    event StakeAdded(
        address indexed owner,
        address indexed LPToken, 
        uint amountLPTokens
    );

    function initialize(
        address _router, 
        address _factory, 
        string memory _name, 
        string memory _symbol
     ) public initializer {
        uniswapRouter = IUniswapV2Router02(_router);
        uniswapFactory = IUniswapV2Factory(_factory);
        __ERC20_init(_name, _symbol);
        __Ownable_init();
    }



    function getBalanceLPTokens(address token) public view returns(uint){
        address pair = uniswapFactory.getPair(token, uniswapRouter.WETH());
        IUniswapV2ERC20 tokenUniswap = IUniswapV2ERC20(pair);
        return tokenUniswap.balanceOf(msg.sender);
    }

    function addLiquidityWithETH(address token) external payable {
        require(msg.value  > 0, "ERROR: Has not been sent ETH");
        uint amountETH = msg.value / 2;
        uint amountTokens = _swapETHForTokens(token, amountETH);
        uint lpTokens = _addLiquidity(token, amountTokens, amountETH);

        IUniswapV2ERC20 tokenUniswap = 
            IUniswapV2ERC20(
                uniswapFactory.getPair(token, uniswapRouter.WETH())
            );
        bool success = tokenUniswap.transfer(msg.sender, lpTokens);
        require(success, "ERROR: Transfer LP Tokens");
        emit LiquidityAdded(msg.sender, token, lpTokens, block.timestamp);
    }

    function addLiquidityAndStake (address token) external payable {
        require(msg.value  > 0, "ERROR: Has not been sent ETH");
        uint amountETH = msg.value / 2;
        uint amountTokens = _swapETHForTokens(token, amountETH);
        uint lpTokens = _addLiquidity(token, amountTokens, amountETH);
        
        address addressPair = uniswapFactory.getPair(token, uniswapRouter.WETH());
        _addStake(addressPair, lpTokens);
        emit LiquidityAdded(msg.sender, token, lpTokens, block.timestamp);
        emit StakeAdded(msg.sender, addressPair, lpTokens);
    }

    function addStake(
        address LPToken, 
        uint amount
     ) public {
        IUniswapV2ERC20 tokenUniswap = IUniswapV2ERC20(LPToken);
        uint allowanceActual = tokenUniswap.allowance(msg.sender, address(this));
        require(allowanceActual >= amount, "ERROR: Not enough tokens to stake");

        bool success = tokenUniswap.transferFrom(msg.sender, address(this),amount);
        require(success, "ERORR: Fail transfer tokens");
        _addStake(LPToken, amount);
        emit StakeAdded(msg.sender, LPToken, amount);
    }

    function addStakeWithPermit(
        address tokenLP,
        uint amount,
        uint deadline,
        bytes32 r, 
        bytes32 s, 
        uint8 v
     ) external {
        IUniswapV2ERC20 tokenUniswap = IUniswapV2ERC20(tokenLP);
        _permitToken(tokenUniswap, msg.sender, amount, deadline, r, s, v);

        bool success = tokenUniswap.transferFrom(msg.sender, address(this), amount);
        require(success, "ERROR: Fail when transfer token");
        _addStake(tokenLP, amount);
        emit StakeAdded(msg.sender, tokenLP, amount);
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

    function _addLiquidity (
        address token, 
        uint amounToken, 
        uint amountETH
     ) internal returns(uint) {
        IERC20 Itoken = IERC20(token);
        Itoken.approve(address(uniswapRouter), amounToken);
        (, , uint liquidity) = uniswapRouter.addLiquidityETH{value:  amountETH}(
            token, amounToken, 
            (amounToken * 9970) / 10000, // 9970 = 99.7% (0.3% slip)
            (amountETH * 9970) / 10000, 
            address(this), 
            block.timestamp + 3600
        );
        return liquidity;
    }

    function _permitToken(
        IUniswapV2ERC20 _tokenLP,
        address _signer,
        uint _amount,
        uint _deadline,
        bytes32 _r, 
        bytes32 _s, 
        uint8 _v
     ) internal {
        _tokenLP.permit(
            _signer, 
            address(this), 
            _amount, 
            _deadline, 
            _v, 
            _r, 
            _s
        );
    }
    
    receive() payable external {} // Only receive the leftover ether
}