// test/ongoing.spec.js
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { ether, nowPlus } = require("./helpers");

describe("Ongoing", function () {
  it("deploys with 8 constructor args", async function () {
    const deadline = nowPlus(30 * 24 * 60 * 60);
    const args = [
      ether("0.01"),
      deadline,
      ether("5"),
      50,
      true,
      0,
      30 * 24 * 60 * 60,
      "0x0000000000000000000000000000000000000000",
    ];

    const Ongoing = await ethers.getContractFactory("Ongoing");
    const og = await Ongoing.deploy(...args);
    await og.deployed();
    expect(og.address).to.properAddress;

    // Optional assertions if getters exist:
    if (og.functions.minimumContribution) {
      expect(await og.minimumContribution()).to.equal(args[0]);
    }
  });
});
