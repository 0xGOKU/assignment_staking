// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract StakingToken is ERC20, Ownable {
    using SafeMath for uint256;

    struct Stake {
        uint rate;
        uint amount;
        uint sinceStaking;
        uint sinceClaimed;
        uint withdrawnAmount;
        uint toWithdraw;
        bool rewarded;
    }

    address[] private stakeHolders;
    mapping(address => Stake[]) private stakes;
    mapping(address => uint) private stakesSummary;
    mapping(address => uint) private rewards;

    uint private _period = 1 hours;
    uint8 private _decimals = 18;

    uint public RATE1 = 1500 * (10**_decimals);
    uint public RATE2 = 1000 * (10**_decimals);
    uint public RATE3 = 100 * (10**_decimals);

    constructor(address _owner, uint initialSupply) ERC20("MyCoolToken", "MCT") {
        _mint(_owner, initialSupply);
    }

    function stake(uint amount) external {
        _burn(msg.sender, amount);
        addToHolders(msg.sender, amount);
    }

    function isStakeHolder(address _stakeHoleder) internal view returns (bool) {
        return stakes[_stakeHoleder].length > 0;
    }

    function addToHolders(address _stakeHoleder, uint amount) internal {
        if (!isStakeHolder(_stakeHoleder)) stakeHolders.push(_stakeHoleder);
        uint stakeRate;
        if (amount > RATE1) stakeRate = 207620;      // 18% per year
        else if (amount > RATE2) stakeRate = 196080; // 17% per year
        else if (amount > RATE3) stakeRate = 184550; // 16% per year
        else stakeRate = 173020;                       // 15% per year
        Stake memory newStake = Stake(stakeRate, amount, block.timestamp, 0, 0, 0, false);
        stakes[msg.sender].push(newStake);
        stakesSummary[msg.sender] += amount;
    }

    function stakeOf(address _stakeHoleder) public view returns(uint) {
        return stakesSummary[_stakeHoleder];
    }

    function countOfStakes(address _stakeHoleder) public view returns(uint) {
        return stakes[_stakeHoleder].length;
    }

    function getStake(address _stakeHoleder, uint stakeIndex) public view returns(Stake memory) {
        return stakes[_stakeHoleder][stakeIndex];
    }

    function calculatePeriod(address _stakeHoleder, uint stakeIndex) public view returns(uint) {
        Stake memory _stake = getStake(_stakeHoleder, stakeIndex);
        uint period = block.timestamp.sub(_stake.sinceStaking).div(3600);
        return period;
    }

    function calculateReward(address _stakeHoleder, uint stakeIndex) public view returns(uint) {
        Stake memory _stake = getStake(_stakeHoleder, stakeIndex);
        uint period = calculatePeriod(_stakeHoleder, stakeIndex);
        return _stake.amount.mul(_stake.rate).mul(period).div(10000000000).sub(_stake.withdrawnAmount);
    }

    function calculateClaim(address _stakeHoleder) internal view returns (uint){
        Stake[] memory _stakes = stakes[_stakeHoleder];

        uint reward = 0;
        uint stakeCount = _stakes.length;

        for(uint i = 0; i < stakeCount; i++)
            reward = reward.add(calculateReward(_stakeHoleder, i));

        return reward;
    }

    function claim() external onlyStakeHolder view returns (uint) {
        return calculateClaim(msg.sender);
    }

    function claimAndWithdraw(uint amount) external onlyStakeHolder {
        require(amount > 0, "Amount to withdraw need to be less than 0");
        uint forReward;
        uint stakeReward;
        uint rewardToWithdraw = 0;
        for (uint i = 0; i < stakes[msg.sender].length; i++) {
            if (rewardToWithdraw == amount) break;

            stakeReward = calculateReward(msg.sender, i);
            forReward = rewardToWithdraw.add(stakeReward);
            if (forReward > amount) {
                forReward = forReward.sub(forReward.sub(amount));
                rewardToWithdraw = forReward;
            } else {
                rewardToWithdraw = forReward;
            }
            stakes[msg.sender][i].toWithdraw = forReward;
            stakes[msg.sender][i].sinceClaimed = block.timestamp;
        }
        require(amount == rewardToWithdraw, "You cant withdraw this amount reward");
    }

    function withdraw() external onlyStakeHolder {
        uint toWithdraw = 0;
        uint rewardToWithdraw = 0;
        for (uint i = 0; i < stakes[msg.sender].length; i++) {
            if (block.timestamp - stakes[msg.sender][i].sinceClaimed < 1 days) continue;
            toWithdraw = stakes[msg.sender][i].toWithdraw;
            rewardToWithdraw = rewardToWithdraw.add(toWithdraw);
            stakes[msg.sender][i].toWithdraw = 0;
            stakes[msg.sender][i].withdrawnAmount += toWithdraw;
            stakes[msg.sender][i].sinceClaimed = 0;
        }
        require(rewardToWithdraw > 0, "You havent withdraws for this time, try again later");
        _mint(msg.sender, rewardToWithdraw);
    }

    /* MODIFIERS */
    modifier onlyStakeHolder {
        require(isStakeHolder(msg.sender), "You need to be a Stakeholder to do that");
        _;
    }

    /* TEST FUNCTIN */

    function _setHoursForStake(address _stakeHoleder, uint stakeIndex, uint _hours) onlyOwner public {
        stakes[_stakeHoleder][stakeIndex].sinceStaking = block.timestamp.sub(_hours.mul(3600));
    }

    function _setHoursForClaimed(address _stakeHoleder, uint stakeIndex, uint _hours) onlyOwner public {
        stakes[_stakeHoleder][stakeIndex].sinceClaimed = block.timestamp.sub(_hours.mul(3600));
    }
}