// scripts/deploy.js (ethers v5 version)
const hre = require("hardhat");
const { artifacts, ethers, network } = hre;
const fs = require("fs");
const path = require("path");

/** ---- tweak here ---- */
const CFG = {
  minimumContribution: ethers.utils.parseEther("0.01"),
  deadlineOffsetSec: 30 * 24 * 60 * 60,  // 30 days
  targetContribution: ethers.utils.parseEther("5"),
  voteThreshold: 50,
  defaultApproveIfNoVote: true,
  votingMode: 0,                          // <-- set to your enum
  transferIntervalSec: 30 * 24 * 60 * 60,
  publicPool: "0x0000000000000000000000000000000000000000",

  donationBadgeHasNameSymbol: false,
  badgeName: "Donation Badge",
  badgeSymbol: "DBADGE",

  registerOneoff: true,
  oneoffTypeLabel: "ONEOFF",

  // demo project meta
  demoTitle: "Demo Oneoff Project",
  demoDesc: "Auto-created by deploy script",
};
/** -------------------- */

async function computeDeadline() {
  const latest = await ethers.provider.getBlock("latest");
  return latest.timestamp + CFG.deadlineOffsetSec; 
}

async function main() {
  console.log(`Network: ${network.name}`);
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const deployed = {};
  const frontendExport = {};
  const deadline = await computeDeadline();

  // ---- DonationBadge ----
  {
    const args = CFG.donationBadgeHasNameSymbol ? [CFG.badgeName, CFG.badgeSymbol] : [];
    const F = await ethers.getContractFactory("DonationBadge");
    const c = await F.deploy(...args);
    await c.deployed();
    const addr = c.address;
    deployed.DonationBadge = c;
    const art = await artifacts.readArtifact("DonationBadge");
    frontendExport.DonationBadge = { address: addr, abi: art.abi };
    console.log("DonationBadge:", addr);
  }

  // ---- ProjectManager ----
  {
    const F = await ethers.getContractFactory("ProjectManager");
    const c = await F.deploy();
    await c.deployed();
    const addr = c.address;
    deployed.ProjectManager = c;
    const art = await artifacts.readArtifact("ProjectManager");
    frontendExport.ProjectManager = { address: addr, abi: art.abi };
    console.log("ProjectManager:", addr);
  }

  // ---- Oneoff (no args) ----
  {
    const F = await ethers.getContractFactory("Oneoff");
    const c = await F.deploy();
    await c.deployed();
    const addr = c.address;
    deployed.Oneoff = c;
    const art = await artifacts.readArtifact("Oneoff");
    frontendExport.Oneoff = { address: addr, abi: art.abi };
    console.log("Oneoff:", addr);
  }

  // ---- Ongoing (8 args) ----
  {
    const F = await ethers.getContractFactory("Ongoing");
    const args = [
      CFG.minimumContribution,
      deadline,
      CFG.targetContribution,
      CFG.voteThreshold,
      CFG.defaultApproveIfNoVote,
      CFG.votingMode,
      CFG.transferIntervalSec,
      CFG.publicPool,
    ];
    const c = await F.deploy(...args);
    await c.deployed();
    const addr = c.address;
    deployed.Ongoing = c;
    const art = await artifacts.readArtifact("Ongoing");
    frontendExport.Ongoing = { address: addr, abi: art.abi };
    console.log("Ongoing:", addr);
  }

  // ---- optional: register Oneoff in ProjectManager ----
  if (CFG.registerOneoff && deployed.ProjectManager && deployed.Oneoff) {
    try {
      const typeHash = ethers.utils.id(CFG.oneoffTypeLabel);
      if (deployed.ProjectManager.registerProjectType) {
        const tx = await deployed.ProjectManager.registerProjectType(typeHash, deployed.Oneoff.address);
        await tx.wait();
        console.log(`Registered Oneoff with type ${CFG.oneoffTypeLabel}`);
      } else {
        console.log("Skipped: ProjectManager.registerProjectType not found.");
      }
    } catch (e) {
      console.log("Registration failed/skipped:", e.message);
    }
  }

  // ---- AUTO CREATE A DEMO PROJECT ON ONEOFF ----
  try {
    const tx = await deployed.Oneoff.createProject(
      CFG.minimumContribution,
      deadline,
      CFG.targetContribution,
      CFG.voteThreshold,
      CFG.defaultApproveIfNoVote,
      CFG.votingMode,
      CFG.demoTitle,
      CFG.demoDesc
    );
    const receipt = await tx.wait();

    let projectAddr;
    try {
      // v5: Interface 在 ethers.utils 下
      const oneoffAbi = (await artifacts.readArtifact("Oneoff")).abi;
      const iface = new ethers.utils.Interface(oneoffAbi);
      for (const log of receipt.logs) {
        try {
          const parsed = iface.parseLog(log);
          if (parsed && parsed.name === "ProjectStarted") {
            projectAddr = parsed.args.projectContractAddress;
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      console.log("Event parsing skipped:", e.message);
    }

    if (!projectAddr) {
      const all = await deployed.Oneoff.returnAllProjects();
      projectAddr = all[all.length - 1];
    }
    console.log("Demo Project created at:", projectAddr);

    const projectArt = await artifacts.readArtifact("Project");
    frontendExport.DemoProject = { address: projectAddr, abi: projectArt.abi };
  } catch (e) {
    console.log("Auto create demo project skipped/failed:", e.message);
  }

  // ---- write for frontend ----
  const outDir = path.join(__dirname, "../client/src/contracts");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, "deployedContracts.json");
  fs.writeFileSync(outPath, JSON.stringify(frontendExport, null, 2));
  console.log("Saved:", outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
