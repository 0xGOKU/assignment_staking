// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Stakeable.sol";
import "./Test.sol";

contract Token is ERC20, Ownable, Stakeable, Test {
    constructor(address _owner, uint256 initialSupply)
        ERC20("MyCoolToken", "MCT")
    {
        _mint(_owner, initialSupply);
    }
}
