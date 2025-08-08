const { expect } = require("chai");
const { ethers } = require("hardhat");

const etherToWei = (n) => ethers.utils.parseUnits(n, "ether");
const dateToUNIX = (date) => Math.round(new Date(date).getTime() / 1000);

describe("Oneoff", () => {
  let oneoff, address1, address2;

  beforeEach(async () => {
    [address1, address2] = await ethers.getSigners();
    const Oneoff = await ethers.getContractFactory("Oneoff");
    oneoff = await Oneoff.deploy();
  });

  it("should create a Project and emit ProjectStarted", async () => {
    const deadline = dateToUNIX("2025-12-31");
    const tx = await oneoff
      .connect(address1)
      .createProject(
        etherToWei("1"),
        deadline,
        etherToWei("5"),
        50,
        true,
        0, // VotingMode enum index
        "Test Title",
        "Test Description"
      );
    const receipt = await tx.wait();
    const evt = receipt.events.find((e) => e.event === "ProjectStarted");
    expect(evt).to.not.be.undefined;
    expect(evt.args.creator).to.equal(address1.address);
    expect(evt.args.title).to.equal("Test Title");

    const all = await oneoff.returnAllProjects();
    expect(all.length).to.equal(1);
  });

  it("should allow contribution to created Project", async () => {
    const deadline = dateToUNIX("2025-12-31");
    await oneoff
      .connect(address1)
      .createProject(
        etherToWei("1"),
        deadline,
        etherToWei("5"),
        50,
        true,
        0,
        "Title",
        "Desc"
      );

    const all = await oneoff.returnAllProjects();
    const targetProjectAddr = all[0];

    const tx = await oneoff
      .connect(address2)
      .contribute(targetProjectAddr, { value: etherToWei("1") });
    const receipt = await tx.wait();
    const evt = receipt.events.find((e) => e.event === "ContributionReceived");
    expect(evt.args.projectAddress).to.equal(targetProjectAddr);
    expect(evt.args.contributor).to.equal(address2.address);
  });
});
