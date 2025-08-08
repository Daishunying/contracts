// test/donationBadge.spec.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DonationBadge", function () {
  let owner, alice, badge;

  beforeEach(async function () {
    [owner, alice] = await ethers.getSigners();
    const Badge = await ethers.getContractFactory("DonationBadge");
    // If your constructor needs (name, symbol), change here accordingly.
    badge = await Badge.deploy();
    await badge.deployed();
  });

  it("deploys", async function () {
    expect(badge.address).to.properAddress;
  });

  it("optionally has ERC721 metadata (name/symbol)", async function () {
    if (!badge.functions.name || !badge.functions.symbol) {
      return this.skip();
    }
    expect(await badge.name()).to.be.a("string");
    expect(await badge.symbol()).to.be.a("string");
  });

  it("optionally mints a badge", async function () {
    // Adjust function name/signature if your contract differs
    if (!badge.functions.mint || !badge.functions.ownerOf) {
      return this.skip();
    }
    const tx = await badge.mint(alice.address, 1);
    await tx.wait();
    expect(await badge.ownerOf(1)).to.equal(alice.address);
  });
});
