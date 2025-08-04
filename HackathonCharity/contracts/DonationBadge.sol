// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DonationBadge is ERC721URIStorage, Ownable {
    uint256 public nextTokenId;

    enum BadgeLevel { Bronze, Silver, Gold }

    struct BadgeConfig {
        uint256 silverThreshold;
        uint256 goldThreshold;
    }

    mapping(address => BadgeConfig) public projectConfigs;

    constructor() ERC721("DonationBadge", "DBADGE") Ownable(msg.sender) {}
    function setBadgeThresholds(address project, uint256 silver, uint256 gold) external onlyOwner {
        require(silver < gold, "Invalid thresholds");
        projectConfigs[project] = BadgeConfig(silver, gold);
    }

    function getBadgeLevel(address project, uint256 amount) public view returns (BadgeLevel) {
        BadgeConfig memory config = projectConfigs[project];
        if (amount >= config.goldThreshold) {
            return BadgeLevel.Gold;
        } else if (amount >= config.silverThreshold) {
            return BadgeLevel.Silver;
        } else {
            return BadgeLevel.Bronze;
        }
    }

    function mintProjectSuccessBadge(address to, string memory projectName, uint256 amount, string memory uri) external onlyOwner {
        uint256 tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function mintDonorBadge(address donor, address project, uint256 amount, string memory uri) external onlyOwner {
        uint256 tokenId = nextTokenId++;
        _safeMint(donor, tokenId);
        _setTokenURI(tokenId, uri);
    }
}
