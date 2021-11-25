// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Stakeable.sol";

abstract contract Test is ERC20, Ownable, Stakeable {
    using SafeMath for uint256;

    /* TEST FUNCTIONS */

    function _setHoursForStake(address stakeHolder, uint256 _hours)
        external
        onlyOwner
    {
        _stakes[stakeHolder].sinceStaking = block.timestamp.sub(
            _hours.mul(3600)
        );
    }

    function _setHoursForClaimed(address stakeHolder, uint256 _hours)
        external
        onlyOwner
    {
        _stakes[stakeHolder].sinceClaimed = block.timestamp.sub(
            _hours.mul(3600)
        );
    }
}
