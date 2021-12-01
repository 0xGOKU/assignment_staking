const { network, ethers } = require("hardhat");
const { expect } = require("chai");

const NAME = 'MyCoolToken'
const SYMBOL = 'MCT'
const MINT_SUPPLY = '1000.0';
const AMOUNT_FOR_STAKE = '100.0';
const YEAR_SECONDS = 8670 * 3600;
const DAY_SECONDS = 86400;


function increaseTime(seconds) {
	return Math.round(new Date().getTime() / 1000) + seconds;
}

var Factory, token, owner, newOwner;
beforeEach(async () => {
	[owner, newOwner] = await ethers.getSigners();
	Factory = await ethers.getContractFactory("Token");
	token = await Factory.deploy(NAME, SYMBOL, owner.address, ethers.utils.parseEther(MINT_SUPPLY)._hex);
	await token.deployed();
})

describe("Deploy and token tests", function () {
	it('check owner contract', async () => {
		expect(await token.owner()).to.equal(owner.address);
	})

	it('has a correct balance minter, name and symbol', async () => {
		const name = await token.name();
		const symbol = await token.symbol();
		const minterBalance = await token.balanceOf(owner.address);

		expect(name).to.equal(NAME);
		expect(symbol).to.equal(SYMBOL);
		expect(minterBalance._hex).to.equal(ethers.utils.parseEther(MINT_SUPPLY)._hex);
	})

	it('transfer ownership', async () => {
		await token.transferOwnership(newOwner.address);
		const currentOwner = await token.owner();
		expect(newOwner.address).to.equal(currentOwner);
	})
})

describe("Stakeable tests", function () {
	it('create stake and claim', async () => {
		const expectedReward = '7.5';
		await token.stake(ethers.utils.parseEther(AMOUNT_FOR_STAKE)._hex);
		await network.provider.send("evm_increaseTime", [YEAR_SECONDS / 2]);
		await token.claim();
		const stake = await token.getStake(owner.address);

		let stakeAmount = stake[0];
		let stakeReward = stake[5];

		expect(ethers.utils.formatEther(stakeAmount)).to.equal(AMOUNT_FOR_STAKE);
		expect(ethers.utils.formatEther(stakeReward)).to.equal(expectedReward);
	})

	it('stake, claimAndWitdhraw and withdraw', async () => {
		let expectedBalance = '1000.0';
		let amountToWithdraw = '200.0';
		let expectedStakeAmount = '49.4';
		let zero = '0.0'

		await token.stake(ethers.utils.parseEther(AMOUNT_FOR_STAKE.toString())._hex);
		await network.provider.send("evm_increaseTime", [YEAR_SECONDS]);
		await token.stake(ethers.utils.parseEther(AMOUNT_FOR_STAKE.toString())._hex);
		await network.provider.send("evm_increaseTime", [YEAR_SECONDS]);
		await token.claimAndWithdraw(ethers.utils.parseEther(amountToWithdraw)._hex);
		await network.provider.send("evm_increaseTime", [DAY_SECONDS]);
		await token.withdraw();
		const balance = await token.balanceOf(owner.address);
		const stake = await token.getStake(owner.address);

		let stakeAmount = stake[0];
		let withdrawnAmount = stake[3];
		let toWithdraw = stake[4];
		let stakeReward = stake[5];

		expect(ethers.utils.formatEther(balance)).to.equal(expectedBalance);
		expect(ethers.utils.formatEther(stakeAmount)).to.equal(expectedStakeAmount);
		expect(ethers.utils.formatEther(withdrawnAmount)).to.equal(amountToWithdraw);
		expect(ethers.utils.formatEther(toWithdraw)).to.equal(zero);
		expect(ethers.utils.formatEther(stakeReward)).to.equal(zero);
	})
})