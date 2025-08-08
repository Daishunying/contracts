// test/helpers.js
const { ethers, artifacts } = require("hardhat");

// parse "1" -> 1 ether in wei (v5)
const ether = (n) => ethers.utils.parseUnits(n, "ether");

// unix now + seconds
const nowPlus = (sec) => Math.floor(Date.now() / 1000) + sec;

// Try to extract Project address from Oneoff's ProjectStarted event.
// Fallback: call returnAllProjects() and return the last one.
async function getProjectAddressFromReceiptOrList(oneoff, receipt) {
  try {
    const oneoffAbi = (await artifacts.readArtifact("Oneoff")).abi;
    const iface = new ethers.utils.Interface(oneoffAbi);
    for (const log of receipt.logs) {
      try {
        const parsed = iface.parseLog(log);
        if (parsed && parsed.name === "ProjectStarted") {
          return parsed.args.projectContractAddress;
        }
      } catch (_) {}
    }
  } catch (_) {}

  const list = await oneoff.returnAllProjects();
  return list[list.length - 1];
}

// Build a Contract instance for Project (it’s likely abstract alone; use deployed address)
async function getProjectInstance(address, signerOrProvider) {
  const art = await artifacts.readArtifact("Project");
  return new ethers.Contract(address, art.abi, signerOrProvider);
}

module.exports = {
  ether,
  nowPlus,
  getProjectAddressFromReceiptOrList,
  getProjectInstance,
};
