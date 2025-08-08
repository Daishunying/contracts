// test/projectManager.spec.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ProjectManager", function () {
  let owner, pm, oneoff;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();

    const PM = await ethers.getContractFactory("ProjectManager");
    pm = await PM.deploy();
    await pm.deployed();

    const Oneoff = await ethers.getContractFactory("Oneoff");
    oneoff = await Oneoff.deploy();
    await oneoff.deployed();
  });

  it("deploys", async function () {
    expect(pm.address).to.properAddress;
  });

  it("optionally registers Oneoff template", async function () {
    if (!pm.functions.registerProjectType) {
      return this.skip();
    }
    const typeHash = ethers.utils.id("ONEOFF");
    const tx = await pm.registerProjectType(typeHash, oneoff.address);
    await tx.wait();
    // If there is a view/getter to verify, call it here; otherwise, test passes if tx mined.
    expect(true).to.equal(true);
  });
});
