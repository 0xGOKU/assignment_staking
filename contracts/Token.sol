// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./StakeableToken.sol";
import "./Test.sol";

contract Token is ERC20, Ownable, StakeableToken, Test {
    using SafeMath for uint256;

    constructor(address _owner, uint256 initialSupply)
        ERC20("MyCoolToken", "MCT")
    {
        _mint(_owner, initialSupply);
    }

    function stake(uint256 amount) external {
        _burn(msg.sender, amount);
        _addToHolders(msg.sender, amount);
    }

    function claim() external view onlyStakeHolder returns (uint256) {
        return _calculateReward(msg.sender);
    }

    function claimAndWithdraw(uint256 amount) external onlyStakeHolder {
        require(amount > 0, "Amount to withdraw need to be less than 0");

        uint256 stakeReward;
        uint256 rewardToWithdraw = 0;

        stakeReward = _calculateReward(msg.sender);
        if (stakeReward > amount) {
            rewardToWithdraw = stakeReward.sub(stakeReward.sub(amount));
        } else {
            rewardToWithdraw = stakeReward;
        }
        _stakes[msg.sender].toWithdraw = rewardToWithdraw;
        _stakes[msg.sender].sinceClaimed = block.timestamp;

        require(
            amount == rewardToWithdraw,
            "You cant withdraw this amount reward"
        );
    }

    function withdraw() external onlyStakeHolder {
        uint256 rewardToWithdraw = 0;

        require(
            block.timestamp - _stakes[msg.sender].sinceClaimed >= 1 days,
            "Minimum withdraw date after claim 1 day."
        );
        rewardToWithdraw = _stakes[msg.sender].toWithdraw;
        _stakes[msg.sender].withdrawnAmount += rewardToWithdraw;
        _stakes[msg.sender].toWithdraw = 0;
        _stakes[msg.sender].sinceClaimed = 0;
        _mint(msg.sender, rewardToWithdraw);
    }
}
