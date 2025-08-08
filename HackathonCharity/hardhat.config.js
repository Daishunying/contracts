require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    holesky: {
      url: process.env.HOLESKY_RPC || "https://holesky.infura.io/v3/" + process.env.INFURA_KEY,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 17000,
    },
    hardhat: {
      chainId: 31337,
    },
  },
};
