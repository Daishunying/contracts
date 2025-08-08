// test/project.spec.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

// helpers (ethers v5)
const ether = (n) => ethers.utils.parseUnits(n, "ether");
const nowPlus = (sec) => Math.floor(Date.now() / 1000) + sec;

describe("Project (unit)", function () {
  let owner, alice, bob, project;

  // constructor:
  // (uint256 _minimumContribution,
  //  uint256 _deadline,
  //  uint256 _targetContribution,
  //  uint256 _voteThreshold,
  //  bool    _defaultApproveIfNoVote,
  //  VotingMode _votingMode)
  const makeArgs = () => ({
    min: ether("1"),
    deadline: nowPlus(30 * 24 * 60 * 60),
    target: ether("10"),
    threshold: 50,               // 50% threshold
    defaultApproveIfNoVote: true,
    votingMode: 0,               // VotingMode.OnePersonOneVote
  });

  beforeEach(async function () {
    [owner, alice, bob] = await ethers.getSigners();
    const Project = await ethers.getContractFactory("Project");
    const a = makeArgs();
    project = await Project.deploy(
      a.min,
      a.deadline,
      a.target,
      a.threshold,
      a.defaultApproveIfNoVote,
      a.votingMode
    );
    await project.deployed();
  });

  it("stores constructor params via getSummary()", async function () {
    const a = makeArgs();
    const summary = await project.getSummary(); // (creator,min,deadline,target,raised,noOf,state,threshold,defaultApprove)
    expect(summary[0]).to.equal(owner.address);
    expect(summary[1]).to.equal(a.min);
    expect(summary[2].toNumber()).to.be.greaterThan(0);
    expect(summary[3]).to.equal(a.target);
    expect(summary[4].toString()).to.equal("0"); // raisedAmount
    expect(summary[5].toString()).to.equal("0"); // noOfContributors
    expect(summary[6].toString()).to.equal("0"); // state: Fundraising
    expect(summary[7]).to.equal(a.threshold);
    expect(summary[8]).to.equal(a.defaultApproveIfNoVote);
  });

  describe("contribute()", function () {
    it("accepts >= minimum and updates counters", async function () {
      await (await project.connect(alice).contribute({ value: ether("2") })).wait();

      // raised & contributors
      const summary = await project.getSummary();
      expect(summary[4]).to.equal(ether("2")); // raisedAmount
      expect(summary[5].toString()).to.equal("1"); // noOfContributors

      // contributors mapping is public? try to read; if not, skip.
      if (project.functions.contributors) {
        const amt = await project.contributors(alice.address);
        expect(amt).to.equal(ether("2"));
      }
    });

    it("reverts if below minimum", async function () {
      await expect(
        project.connect(alice).contribute({ value: ether("0.5") })
      ).to.be.revertedWith("Contribution amount is too low");
      // 上面的 revert message 取决于你合约实际写法，若不一致可改为 .to.be.reverted
    });

    it("switches state to Successful when target reached", async function () {
      await (await project.connect(alice).contribute({ value: ether("6") })).wait();
      await (await project.connect(bob).contribute({ value: ether("5") })).wait();

      const summary = await project.getSummary();
      expect(summary[6].toString()).to.equal("2"); // Successful = 2
    });
  });

  describe("withdraw request flow", function () {
    beforeEach(async function () {
      // 先筹满一些钱，方便后续提现
      await (await project.connect(alice).contribute({ value: ether("6") })).wait();
      await (await project.connect(bob).contribute({ value: ether("6") })).wait();
    });

    it("only creator can create a request", async function () {
      // 你的 create 函数如果需要 voteDuration（或 voteDeadline）参数，这里传 例如 7 天
      const createFn = project.functions.createWithdrawRequest;
      if (!createFn) return this.skip();

      await expect(
        project.connect(alice).createWithdrawRequest("ops", ether("2"), alice.address, 7 * 24 * 60 * 60)
      ).to.be.reverted; // 非 creator

      const tx = await project
        .connect(owner)
        .createWithdrawRequest("ops", ether("2"), owner.address, 7 * 24 * 60 * 60);
      await tx.wait();

      // 如果有 numOfWithdrawRequests() 或其它 getter，可以断言一下
      if (project.functions.numOfWithdrawRequests) {
        const n = await project.numOfWithdrawRequests();
        expect(n.toNumber()).to.equal(1);
      }
    });

    it("only contributors can vote; cannot double vote", async function () {
      if (!project.functions.voteWithdrawRequest || !project.functions.createWithdrawRequest) {
        return this.skip();
      }
      await (await project.connect(owner).createWithdrawRequest("ops", ether("2"), owner.address, 7 * 24 * 60 * 60)).wait();

      // 非捐款人投票应失败（如果合约这样写）
      await expect(
        project.connect(owner).voteWithdrawRequest(0)
      ).to.be.reverted; // 具体消息按你合约为准

      // 捐款人可投票
      await (await project.connect(alice).voteWithdrawRequest(0)).wait();

      // 不能重复投
      await expect(
        project.connect(alice).voteWithdrawRequest(0)
      ).to.be.revertedWith("Already voted"); // 按你合约里的字符串
    });

    it("creator can finalize when threshold met / or defaultApproveIfNoVote applies", async function () {
      if (!project.functions.finalizeWithdrawRequest || !project.functions.createWithdrawRequest) {
        return this.skip();
      }
      await (await project.connect(owner).createWithdrawRequest("ops", ether("2"), owner.address, 7 * 24 * 60 * 60)).wait();

      // 投票达到阈值（2位捐助者 → 票权取决于 votingMode；这里先都投一票）
      if (project.functions.voteWithdrawRequest) {
        await (await project.connect(alice).voteWithdrawRequest(0)).wait();
        await (await project.connect(bob).voteWithdrawRequest(0)).wait();
      }

      const receipt = await (await project.connect(owner).finalizeWithdrawRequest(0)).wait();
      // 如果有事件可解析就解析；否则至少不 revert 即通过
      expect(receipt.status).to.equal(1);
    });
  });
});
