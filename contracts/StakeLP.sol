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
    // Domain
    uint256 chainId;
    address verifyingContract;
    string private EIP712_DOMAIN;
    bytes32 private EIP712_DOMAIN_TYPEHASH;
    bytes32 private DOMAIN_SEPARATOR ;

    struct Offer {
        uint256 amount;
        address wallet;
    }
    string private constant OFFER_TYPE = "Offer(uint256 amount,address wallet)";
    bytes32 private OFFER_TYPEHASH;

    IUniswapV2Router02 uniswapRouter;
    event LiquidityAdded(
        address indexed sender,
        address indexed token, 
        uint amountLPTokens, 
        uint time
    );

    function initialize(address _router, uint _chainId) public initializer {
        uniswapRouter = IUniswapV2Router02(_router);
        __init_EIP712(_chainId);
    }

    function __init_EIP712(uint _chainId) public initializer {
        verifyingContract = address(this);
        chainId = _chainId;
        // Domain
        EIP712_DOMAIN = 
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)";

        // TYPEHASH
        EIP712_DOMAIN_TYPEHASH = keccak256(abi.encodePacked(EIP712_DOMAIN));
        OFFER_TYPEHASH = keccak256(abi.encodePacked(OFFER_TYPE));

        // SEPRATOR
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256("Stake Contract"),
            chainId,
            verifyingContract
        ));
    }

    function verify(
        address signer, 
        Offer memory offer, 
        bytes32 sigR, 
        bytes32 sigS, 
        uint8 sigV
    ) public view returns (bool) {
        return signer == ecrecover(_hashOffer(offer), sigV, sigR, sigS);
    }

    function _hashOffer(Offer memory offer) private view returns (bytes32){
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                OFFER_TYPEHASH,
                offer.amount,
                offer.wallet
            ))
        ));
    }

    function getBalanceLPTokens(address token) public view returns(uint){
        IUniswapV2Factory factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        address pair = factory.getPair(token, uniswapRouter.WETH());
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

    function stakeLPTokens (address token) public payable {
        
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