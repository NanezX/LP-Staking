// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";


contract StakeToken is ERC20Upgradeable, OwnableUpgradeable {
    uint rewardConstant;
    event RewardClaimed (
        address to,
        uint amountSTK,
        uint timeClaimed
    );
    struct Stake {
        uint amount;
        uint timestamp;
        uint decimals;
    }
    mapping(address => mapping(address=>Stake)) internal stakes;
    mapping(address => uint256)internal totalStakes;

    function __init_StakeToken(string memory _name, string memory _symbol) public initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        rewardConstant = (10 ** 17)*5;
    }

    function getTotalStakes(
        address[] memory _LPToken
    ) external view returns(uint256[] memory) {
        uint length = _LPToken.length;
        uint[] memory stakesTotal = new uint[](length);
        for(uint i; i<length; i++) {
            stakesTotal[i] = totalStakes[_LPToken[i]];
        }
        return stakesTotal;
    }

    function _addStake(address _LPToken, uint _amount, uint _decimals) internal {
        require(
            stakes[address(_LPToken)][msg.sender].amount == 0,
            "ERROR: Have an actual stake on this token"
        );
        stakes[address(_LPToken)][msg.sender] = Stake(_amount, block.timestamp, _decimals);
        totalStakes[_LPToken] += _amount;
    }

    function stakeOf(address LPToken) external view returns(uint){
        return stakes[address(LPToken)][msg.sender].amount;
    }

    // Get as reward: the days while was staking (time), mutiplied by the 0.1%
    // of the amount staked (by ), and multiplied by 1 STK
    function _getReward(address _LPToken) internal {
        Stake memory stake = stakes[address(_LPToken)][msg.sender];
        require(
            stake.amount != 0,
            "ERROR: Not have any stake"
        );
        uint time = block.timestamp - stake.timestamp;
        uint reward;
        if(time < 86400) {
            time = 0;
        } else {
            if (time % 86400 == 0) {
                time = (time / 86400);
            } else {
                time = (time - time % 86400) / 86400;
            }
        }
        if (stake.decimals == 18) {
            reward = time * (stake.amount * 10 / 10000) * rewardConstant;
        } else {
            uint decimal = 18 - stake.decimals;
            if (decimal == 1) {
                decimal = 10;
            } else {
                decimal = 10**decimal;
            }
            reward = time * ( (stake.amount * decimal) * 10 / 10000) * rewardConstant;
        }
        _mint(msg.sender, reward);
        _removeStake(_LPToken, stake.amount);
        emit RewardClaimed(msg.sender, reward, block.timestamp);
    }

    function _removeStake(address _LPToken, uint _amount) internal{
        bool success = IUniswapV2ERC20(_LPToken).transfer(msg.sender, _amount);
        require(success, "ERROR: Failed when return the LP tokens");
        totalStakes[_LPToken] -= stakes[address(_LPToken)][msg.sender].amount;
        delete stakes[address(_LPToken)][msg.sender];
    }
}