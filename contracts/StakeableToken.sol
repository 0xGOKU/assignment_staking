// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

abstract contract StakeableToken is ERC20, Ownable {
    using SafeMath for uint256;
    struct Stake {
        uint256 amount;
        uint256 sinceStaking;
        uint256 sinceClaimed;
        uint256 withdrawnAmount;
        uint256 toWithdraw;
        uint256 reward;
        uint256 freezeAmount;
    }

    mapping(address => Stake) internal _stakes;
    mapping(address => bool) internal _stakeHolders;

    uint256 public YEAR_HOURS = 8670;
    uint256 public MIN_WITHDRAW_PERIOD = 1 days;

    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    {}

    /* INTERNAL FUNCTIONS */

    function _getRate(uint256 _amount) internal view returns (uint256) {
        if (_amount <= 100 * 10**decimals()) return 15; // 15% APY
        if (_amount <= 1000 * 10**decimals()) return 16; // 16% APY
        if (_amount <= 1500 * 10**decimals()) return 17; // 17% APY
        return 18; // 18% APY
    }

    function _isStakeHolder(address _stakeHolder) internal view returns (bool) {
        return _stakeHolders[_stakeHolder];
    }

    function _addToHolders(address _stakeHolder) internal {
        if (!_isStakeHolder(_stakeHolder)) _stakeHolders[_stakeHolder] = true;
    }

    function _stake(address _stakeHolder, uint256 _amount) internal {
        Stake memory stake_;
        if (!_isStakeHolder(_stakeHolder)) {
            stake_ = _createNewStake(_amount);
            _addToHolders(_stakeHolder);
        } else {
            unfreezeAmount(_stakeHolder);
            stake_ = getStake(_stakeHolder);
            uint256 actualReward = _calculateReward(_stakeHolder);
            stake_.freezeAmount += actualReward.add(stake_.amount);
            stake_.amount = _amount;
            stake_.sinceClaimed = block.timestamp;
        }
        stake_.sinceStaking = block.timestamp;
        _stakes[_stakeHolder] = stake_;
    }

    function _claim(address _stakeHolder) internal {
        unfreezeAmount(_stakeHolder);
        _stakes[_stakeHolder].reward = _calculateReward(_stakeHolder);
        _stakes[_stakeHolder].sinceClaimed = block.timestamp;
    }

    function unfreezeAmount(address _stakeHolder) internal {
        if (
            block.timestamp - _stakes[_stakeHolder].sinceStaking >=
            MIN_WITHDRAW_PERIOD &&
            _stakes[_stakeHolder].freezeAmount > 0
        ) {
            _stakes[_stakeHolder].amount += _stakes[_stakeHolder].freezeAmount;
            _stakes[_stakeHolder].freezeAmount = 0;
        }
    }

    function _claimAndWithdraw(address _stakeHolder, uint256 _amount) internal {
        require(_amount > 0, "Amount to withdraw need to be less than 0");

        _claim(_stakeHolder);
        uint256 maxAmount = _stakes[_stakeHolder].amount.add(
            _stakes[_stakeHolder].reward
        );
        require(_amount <= maxAmount, "You cant withdraw this amount");
        _stakes[_stakeHolder].toWithdraw = _amount;
        _stakes[_stakeHolder].reward = 0;
        _stakes[_stakeHolder].amount = maxAmount.sub(_amount);
    }

    function _withdraw(address _stakeHolder) internal returns (uint256) {
        Stake memory stake_ = getStake(_stakeHolder);

        require(
            block.timestamp - stake_.sinceClaimed >= MIN_WITHDRAW_PERIOD,
            "Minimum withdraw period after claim 1 day."
        );

        uint256 toWithdraw = stake_.toWithdraw;
        stake_.withdrawnAmount = stake_.withdrawnAmount.add(toWithdraw);
        stake_.toWithdraw = 0;
        stake_.sinceStaking = block.timestamp;
        _stakes[_stakeHolder] = stake_;
        return toWithdraw;
    }

    function _createNewStake(uint256 _amount)
        internal
        view
        returns (Stake memory)
    {
        return
            Stake({
                amount: _amount,
                sinceStaking: block.timestamp,
                sinceClaimed: block.timestamp,
                withdrawnAmount: 0,
                toWithdraw: 0,
                reward: 0,
                freezeAmount: 0
            });
    }

    function _calculatePeriod(address _stakeHolder)
        internal
        view
        returns (uint256)
    {
        return
            block.timestamp.sub(_stakes[_stakeHolder].sinceStaking).div(3600);
    }

    function _calculateReward(address _stakeHolder)
        internal
        view
        returns (uint256)
    {
        uint256 stakeAmount = _stakes[_stakeHolder].amount;
        uint256 periodHours = _calculatePeriod(_stakeHolder);
        uint256 rate = _getRate(stakeAmount);
        uint256 reward = stakeAmount.mul(rate).mul(periodHours).div(100).div(
            YEAR_HOURS
        );
        return reward;
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
