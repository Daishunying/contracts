require("dotenv").config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan"); 
// 如果装了 waffle，就加这一行
// require("@nomiclabs/hardhat-waffle");

const { PRIVATE_KEY, ALCHEMY_API_KEY, ETHERSCAN_API_KEY } = process.env;

module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {},
    holesky: {
      url: `https://eth-holesky.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      chainId: 17000,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
    customChains: [
      {
        network: "holesky",
        chainId: 17000,
        urls: {
          apiURL: "https://api-holesky.etherscan.io/api",
          browserURL: "https://holesky.etherscan.io",
        },
      },
    ],
  },
};
