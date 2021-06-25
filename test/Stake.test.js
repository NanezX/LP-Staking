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
let stakeI, IDAI, tx;

// TOKEN OWNERS
const DAI_OWNER = "0x16463c0fdb6ba9618909f5b120ea1581618c1b9e";

describe("Stake Contract", ()=>{
    beforeEach(async()=>{
        IDAI = await ethers.getContractAt("IERC20",  DAI_ADDRESS);

    });
    it("Swapping", async ()=>{
         // Getting hardhat accounts
        const [account1, account2, account3, ...accounts] = await ethers.getSigners();
        const factory = await ethers.getContractFactory("StakeLP");
        stakeI = await upgrades.deployProxy(factory, [UniswapRouter]);

        
        tx = await stakeI.addLiquidityWithETH(
            DAI_ADDRESS,
            {value:ethers.utils.parseEther("1")}
        );
    
        // await IDAI.balanceOf(account1.getAddress())
    });
});