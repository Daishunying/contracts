// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DonationCertificateNFT is ERC721URIStorage, Ownable {
    uint256 public nextTokenId;
    mapping(address => bool) public hasCreatorCertificate;

    constructor() ERC721("Donation Certificate", "CERT") Ownable(msg.sender) {}

    function mintCreatorCertificate(address to, uint projectId) external onlyOwner {
        require(!hasCreatorCertificate[to], "Already has creator certificate");
        uint tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked("ipfs://creator/", uint2str(projectId))));
        hasCreatorCertificate[to] = true;
    }

    function mintDonorCertificate(address to, uint projectId, uint tier) external onlyOwner {
        uint tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        string memory tierStr = tier == 1 ? "bronze" : (tier == 2 ? "silver" : "gold");
        _setTokenURI(tokenId, string(abi.encodePacked("ipfs://donor/", tierStr, "/", uint2str(projectId))));
    }

    function uint2str(uint _i) internal pure returns (string memory str) {
        if (_i == 0) return "0";
        uint j = _i; uint len;
        while (j != 0) { len++; j /= 10; }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            bstr[--k] = bytes1(uint8(48 + _i % 10));
            _i /= 10;
        }
        str = string(bstr);
    }
}
