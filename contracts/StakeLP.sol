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
    IUniswapV2Factory uniswapFactory;
    event LiquidityAdded(
        address indexed sender,
        address indexed token, 
        uint amountLPTokens, 
        uint time
    );

    function initialize(address _router, address _factory, uint _chainId) public initializer {
        uniswapRouter = IUniswapV2Router02(_router);
        uniswapFactory = IUniswapV2Factory(_factory);
        _init_EIP712(_chainId);
    }


    function _init_EIP712(uint _chainId) internal initializer {
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

    function verifyUni (
        address token,
        address signer,
        uint deadline,
        bytes32 r, 
        bytes32 s, 
        uint8 v
     ) public view returns(bool) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                IUniswapV2ERC20(uniswapFactory.getPair(token, uniswapRouter.WETH())).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        IUniswapV2ERC20(uniswapFactory.getPair(token, uniswapRouter.WETH())).PERMIT_TYPEHASH(),
                        signer,
                        address(this),
                        IUniswapV2ERC20(uniswapFactory.getPair(token, uniswapRouter.WETH())).balanceOf(signer),
                        uint256(IUniswapV2ERC20(uniswapFactory.getPair(token, uniswapRouter.WETH())).nonces(signer)),
                        deadline
                    )
                )
            )
        );
        return signer == ecrecover(digest, v, r, s);
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