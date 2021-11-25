const assert = require("assert");
const ganache = require("ganache-cli");
const Web3 = require("web3");

const provider = ganache.provider();
const web3 = new Web3(provider);
const { abi, bytecode } = require("../build/contracts/Token");

const NAME = "MyCoolToken";
const SYMBOL = "MCT";
let accounts;
let token;
const mintSupply = 1000;

beforeEach(async () => {
  accounts = await web3.eth.getAccounts();

  token = await new web3.eth.Contract(abi)
    .deploy({
      data: bytecode,
      arguments: [
        accounts[0],
        web3.utils.toWei(mintSupply.toString(), "ether"),
      ],
    })
    .send({ from: accounts[0], gas: "5000000", gasPrice: "100" });

  token.setProvider(provider);
});

describe("StakeableToken", () => {
  it("deploys a token contract", () => {
    assert.ok(token.options.address);
  });

  it("has a correct balance minter, name and symbol", async () => {
    const name = await token.methods.name().call();
    assert.strictEqual(name, NAME);

    const symbol = await token.methods.symbol().call();
    assert.strictEqual(symbol, SYMBOL);

    const minterBalance = await token.methods.balanceOf(accounts[0]).call();
    assert.strictEqual(
      minterBalance,
      web3.utils.toWei(mintSupply.toString(), "ether")
    );
  });

  it("transfer ownership", async () => {
    const oldOwner = await token.methods.owner().call();
    assert.strictEqual(oldOwner, accounts[0]);

    await token.methods
      .transferOwnership(accounts[1])
      .send({ from: accounts[0] });
    const newOwner = await token.methods.owner().call();
    assert.strictEqual(newOwner, accounts[1]);
  });

  it("create stake with some amount", async () => {
    const amountForStake = 100;
    await token.methods
      .stake(web3.utils.toWei(amountForStake.toString(), "ether"))
      .send({
        from: accounts[0],
        gas: "500000",
      });
    const stakeAmount = await token.methods.stakeOf(accounts[0]).call();
    assert.strictEqual(
      stakeAmount,
      web3.utils.toWei(amountForStake.toString(), "ether")
    );
  });

  it("stake and check reward after some period", async () => {
    const amountForStake = 100;
    await token.methods
      .stake(web3.utils.toWei(amountForStake.toString(), "ether"))
      .send({
        from: accounts[0],
        gas: "500000",
      });

    const stake = await token.methods.getStake(accounts[0]).call();
    const rate = parseInt(stake[0], 10) / 100000000;

    let hours = [0, 1, 729, 8670];
    for (let i = 0; i < hours.length; i++) {
      await token.methods
        ._setHoursForStake(accounts[0], hours[i])
        .send({ from: accounts[0], gas: "50000" });
      let reward = await token.methods.claim().call();
      let expectedAward = Math.round(rate * hours[i] * 10000000) / 10000000;
      assert.strictEqual(
        expectedAward.toString(),
        web3.utils.fromWei(reward, "ether")
      );
    }
  });

  it("stake, claimAndWitdhraw and withdraw", async () => {
    const amountForStake = 100;
    await token.methods
      .stake(web3.utils.toWei(amountForStake.toString(), "ether"))
      .send({
        from: accounts[0],
        gas: "500000",
      });

    await token.methods
      ._setHoursForStake(accounts[0], 729)
      .send({ from: accounts[0], gas: "50000" });

    let stake = await token.methods.getStake(accounts[0]).call();
    const rate = parseInt(stake[0], 10) / 100000000;
    let withdrawReward = rate * 729 + 1; // to withdraw more than available

    try {
      await token.methods
        .claimAndWithdraw(web3.utils.toWei(withdrawReward.toString(), "ether"))
        .send({ from: accounts[0], gas: "500000" });
      assert(false);
    } catch (e) {
      assert(true);
    }

    withdrawReward = rate * 729;
    await token.methods
      .claimAndWithdraw(web3.utils.toWei(withdrawReward.toString(), "ether"))
      .send({ from: accounts[0], gas: "500000" });
    stake = await token.methods.getStake(accounts[0]).call();
    assert.strictEqual(
      stake[5],
      web3.utils.toWei(withdrawReward.toString(), "ether")
    );

    await token.methods
      ._setHoursForClaimed(accounts[0], 24)
      .send({ from: accounts[0], gas: "50000" });

    let balanceBeforeWithdraw = await token.methods
      .balanceOf(accounts[0])
      .call();
    await token.methods.withdraw().send({ from: accounts[0], gas: "500000" });
    stake = await token.methods.getStake(accounts[0]).call();
    assert.strictEqual(
      stake[4],
      web3.utils.toWei(withdrawReward.toString(), "ether")
    );

    let balance = await token.methods.balanceOf(accounts[0]).call();
    let expectedBalance =
      parseInt(balanceBeforeWithdraw, 10) + parseInt(stake[4], 10);
    assert.strictEqual(
      web3.utils.toWei(balance.toString(), "ether"),
      web3.utils.toWei(expectedBalance.toString(), "ether")
    );
  });

  it("stake one more time and withdraw", async () => {
    const amountForStake = 100;
    await token.methods
      .stake(web3.utils.toWei(amountForStake.toString(), "ether"))
      .send({
        from: accounts[0],
        gas: "500000",
      });

    const hours = 729;
    await token.methods
      ._setHoursForStake(accounts[0], hours)
      .send({ from: accounts[0], gas: "50000" });

    let stake = await token.methods.getStake(accounts[0]).call();
    const firstRate = parseInt(stake[0], 10) / 100000000;

    await token.methods
      .stake(web3.utils.toWei(amountForStake.toString(), "ether"))
      .send({
        from: accounts[0],
        gas: "500000",
      });

    const balance = await token.methods.balanceOf(accounts[0]).call();
    const expectedBalance = mintSupply - amountForStake * 2;
    assert.strictEqual(
      balance,
      web3.utils.toWei(expectedBalance.toString(), "ether")
    );

    stake = await token.methods.getStake(accounts[0]).call();
    const newRate = stake[0];
    const expectedRate = "184550";
    assert.strictEqual(newRate, expectedRate);

    const stakeAmount = stake[1];
    const expectedAmount =
      amountForStake * 2 + Math.round(hours * firstRate * 10000000) / 10000000;
    assert.strictEqual(
      stakeAmount,
      web3.utils.toWei(expectedAmount.toString(), "ether")
    );
  });
});
