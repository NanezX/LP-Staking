// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";


contract StakeToken is ERC20Upgradeable, OwnableUpgradeable {
    mapping(address => mapping(address=>uint))internal stakes;
    mapping(address => uint256)internal totalStakes;

    function _addStake(address _LPToken, uint _amount) internal {
        stakes[address(_LPToken)][msg.sender] += _amount;
    }

    function stakeOf(address _stakeholder, address _LPToken) public view returns(uint256) {
       return stakes[_LPToken][_stakeholder];
    }

    function getTotalStakes(address _LPToken) public view returns(uint256) {
        return totalStakes[_LPToken];
    }

}