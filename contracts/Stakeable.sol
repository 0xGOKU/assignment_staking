// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract Stakeable is ERC20, Ownable {
    using SafeMath for uint256;

    struct Stake {
        uint256 rate;
        uint256 amount;
        uint256 sinceStaking;
        uint256 sinceClaimed;
        uint256 withdrawnAmount;
        uint256 toWithdraw;
    }

    mapping(address => Stake) internal _stakes;
    mapping(address => bool) internal _stakeHolders;

    uint8 internal _decimals = 18;

    uint256 public RATE1 = 1500 * (10**_decimals);
    uint256 public RATE2 = 1000 * (10**_decimals);
    uint256 public RATE3 = 100 * (10**_decimals);

    /* EXTERNAL FUNCTIONS */

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

    /* INTERNAL FUNCTIONS */

    function _isStakeHolder(address _stakeHolder) internal view returns (bool) {
        return _stakeHolders[_stakeHolder];
    }

    function _getStakeRate(uint256 _amount) internal view returns (uint256) {
        uint256 stakeRate;
        if (_amount > RATE1)
            stakeRate = 207620; // 18% per year
        else if (_amount > RATE2)
            stakeRate = 196080; // 17% per year
        else if (_amount > RATE3)
            stakeRate = 184550; // 16% per year
        else stakeRate = 173020; // 15% per year
        return stakeRate;
    }

    function _addToHolders(address _stakeHolder, uint256 _amount) internal {
        Stake memory _stake;
        if (!_isStakeHolder(_stakeHolder)) {
            _stakeHolders[msg.sender] = true;
            _stake = Stake({
                rate: _getStakeRate(_amount),
                amount: _amount,
                sinceStaking: block.timestamp,
                sinceClaimed: 0,
                withdrawnAmount: 0,
                toWithdraw: 0
            });
        } else {
            _stake = getStake(_stakeHolder);
            _stake.amount = _stake
                .amount
                .add(_calculateReward(_stakeHolder))
                .add(_amount);
            _stake.rate = _getStakeRate(_stake.amount);
            _stake.sinceStaking = block.timestamp;
        }
        _stakes[msg.sender] = _stake;
    }

    function _calculatePeriod(address _stakeHolder)
        internal
        view
        returns (uint256)
    {
        Stake memory _stake = getStake(_stakeHolder);
        return block.timestamp.sub(_stake.sinceStaking).div(3600);
    }

    function _calculateReward(address _stakeHolder)
        internal
        view
        returns (uint256)
    {
        Stake memory _stake = getStake(_stakeHolder);
        uint256 period = _calculatePeriod(_stakeHolder);
        return
            _stake.amount.mul(_stake.rate).mul(period).div(10000000000).sub(
                _stake.withdrawnAmount
            );
    }

    /* PUBLIC FUNCTIONS */

    function stakeOf(address stakeHolder) public view returns (uint256) {
        return _stakes[stakeHolder].amount;
    }

    function getStake(address stakeHolder) public view returns (Stake memory) {
        return _stakes[stakeHolder];
    }

    /* MODIFIERS */

    modifier onlyStakeHolder() {
        require(
            _isStakeHolder(msg.sender),
            "You need to be a Stakeholder to do that"
        );
        _;
    }
}
