const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const hre = require("hardhat");

/*
With router V2: 159k gas
*/

// Token adresses
const DAI_ADDRESS = "0x6b175474e89094c44da98b954eedeac495271d0f";
const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const USDC_ADDRESS = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
const LINK_ADDRESS = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
const UNI_ADDRESS = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

// Test variables / constants
const UniswapRouter = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const UniswapFactory = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
let stakeI, IDAI, IUniswapV2ERC20, IUniswapFactory, tx;
let eventFilter, event;
let account1, account2, account3, accounts;

// TOKEN OWNERS
const DAI_OWNER = "0x16463c0fdb6ba9618909f5b120ea1581618c1b9e";

describe("Stake Contract", ()=>{
    before(async()=>{
        // Getting accounts
        [account1, account2, account3, ...accounts] = await ethers.getSigners();
        // Deploy
        const factory = await ethers.getContractFactory("StakeLP");
        stakeI = await upgrades.deployProxy(
            factory, 
            [
                UniswapRouter,
                UniswapFactory,
                 1
            ]);
        // Interface Dai Token
        IDAI = await ethers.getContractAt("IERC20",  DAI_ADDRESS);
    });
    it("Should add liquidity", async ()=>{
        tx = await stakeI.addLiquidityWithETH(
            DAI_ADDRESS,
            {value:ethers.utils.parseEther("1")}
        );
        tx = await tx.wait();

        eventFilter = await stakeI.filters.LiquidityAdded(); 
        event = await stakeI.queryFilter(eventFilter, "latest");
        const LPTokensObtained = event[0].args.amountLPTokens.toString()
        const balance = await stakeI.getBalanceLPTokens(DAI_ADDRESS);

        expect(LPTokensObtained).to.be.equal(balance);
    });
    it("Should return true the signature verification", async ()=>{
         const domain = {
            name: 'Stake Contract',
            chainId: 1,
            verifyingContract: stakeI.address
        };
        
        const types = {
            Offer: [
                { name: 'amount', type: 'uint256' },
                { name: 'wallet', type: 'address' }
            ]
        };
        
        // The data to sign
        const value = {
            amount: '100',
            wallet: await account1.getAddress()
        };
        
        let signature = await account1._signTypedData(domain, types, value);
        signature = signature.substring(2)
        const r = "0x" + signature.substring(0, 64);
        const s = "0x" + signature.substring(64, 128);
        const v = parseInt(signature.substring(128, 130), 16);
        let isVerify = await stakeI.verify(
            await account1.getAddress(),
            value,
            r,
            s,
            v
        );
        expect(isVerify).to.be.true;
    });
    it("Stake with Permit", async ()=> {
        IUniswapFactory = await ethers.getContractAt("IUniswapV2Factory", UniswapFactory);
        const pairDAI_WETH = await IUniswapFactory.getPair(DAI_ADDRESS, WETH_ADDRESS);
        const IUniswapV2ERC20 = await ethers.getContractAt("IUniswapV2ERC20", pairDAI_WETH)

        const allowanceBefore = await IUniswapV2ERC20.allowance(await account1.getAddress(), stakeI.address);

        // EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)
        const domain = {
            name: await IUniswapV2ERC20.name(),
            version: "1",
            chainId: 1,
            verifyingContract: pairDAI_WETH
        };
        // Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)
        const types = {
            Permit: [
                { name: 'owner', type: 'address' },
                { name: 'spender', type: 'address' },
                { name: 'value', type: 'uint256' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ]
        };

        const value = {
            owner: await account1.getAddress(),
            spender: stakeI.address,
            value: (await IUniswapV2ERC20.balanceOf(await account1.getAddress())).toString(),
            nonce: (await IUniswapV2ERC20.nonces(await account1.getAddress())).toString(),
            deadline: Date.now() + 120
        };
        let signature = await account1._signTypedData(domain, types, value);
        signature = signature.substring(2)
        const r = "0x" + signature.substring(0, 64);
        const s = "0x" + signature.substring(64, 128);
        const v = parseInt(signature.substring(128, 130), 16);

        tx = await stakeI.permitToken(
            DAI_ADDRESS,
            await account1.getAddress(),
            value.deadline,
            r,
            s,
            v
        );
        const allowanceAfter = await IUniswapV2ERC20.allowance(await account1.getAddress(), stakeI.address);
        expect(allowanceAfter).to.be.above(allowanceBefore)
    })
});

// Filter an event
// eventFilter = await stakeI.filters.LiquidityAdded(); 
// event = await stakeI.queryFilter(eventFilter, "latest");
// requestId = event[0].args.amountLPTokens;

// Mine
// await hre.network.provider.send("evm_mine");

// Get block
// let block = await hre.network.provider.send("eth_blockNumber");

// (await ethers.provider.getNetwork()).chainId
// (await ethers.provider.getNetwork()).chainId

/// Just in case
// https://github.com/0xsequence/ethers-eip712