// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./StakeableToken.sol";

contract Token is StakeableToken {
    using SafeMath for uint256;

    constructor(
        string memory name_,
        string memory symbol_,
        address _owner,
        uint256 initialSupply
    ) StakeableToken(name_, symbol_) {
        _mint(_owner, initialSupply);
    }

    function stake(uint256 amount) external {
        _burn(msg.sender, amount);
        _stake(msg.sender, amount);
    }

    function claim() external onlyStakeHolder {
        _claim(msg.sender);
    }

    function claimAndWithdraw(uint256 amount) external onlyStakeHolder {
        _claimAndWithdraw(msg.sender, amount);
    }

    function withdraw() external onlyStakeHolder {
        uint256 toWithdraw = _withdraw(msg.sender);
        _mint(msg.sender, toWithdraw);
    }
}
