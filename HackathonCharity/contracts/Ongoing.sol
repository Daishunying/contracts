// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Project.sol";

contract Ongoing is Project {
    uint256 public lastTransferTimestamp;
    uint256 public transferInterval; // seconds between monthly transfers
    bool public stopped = false;
    address public publicPool;

    struct Evidence {
        string ipfsHash;
        uint256 timestamp;
        bool approved;
    }

    Evidence[] public evidences;

    event ProjectStopped(uint256 remainingAmountMovedToPool);
    event EvidenceUploaded(string ipfsHash, uint256 index);
    event EvidenceApproved(uint256 index);

    constructor(
        uint256 _minimumContribution,
        uint256 _deadline,
        uint256 _targetContribution,
        uint256 _voteThreshold,
        bool _defaultApproveIfNoVote,
        VotingMode _votingMode,
        uint256 _transferInterval,
        address _publicPool
    ) Project(
        _minimumContribution,
        _deadline,
        _targetContribution,
        _voteThreshold,
        _defaultApproveIfNoVote,
        _votingMode
    ) {
        transferInterval = _transferInterval;
        lastTransferTimestamp = block.timestamp;
        publicPool = _publicPool;
    }

    function monthlyTransfer(address payable recipient, uint256 amount) external onlyCreator {
        require(!stopped, "Project stopped");
        require(block.timestamp >= lastTransferTimestamp + transferInterval, "Wait until next interval");
        require(state == State.Successful, "Project not successful yet");
        require(address(this).balance >= amount, "Insufficient balance");

        recipient.transfer(amount);
        lastTransferTimestamp = block.timestamp;
    }

    function checkAndMaybeStopProject() external {
        require(!stopped, "Already stopped");
        if (raisedAmount < targetContribution) {
            stopped = true;
            uint256 balanceToPool = address(this).balance;
            payable(publicPool).transfer(balanceToPool);
            emit ProjectStopped(balanceToPool);
        }
    }

    function uploadEvidence(string memory ipfsHash) external onlyCreator {
        evidences.push(Evidence(ipfsHash, block.timestamp, false));
        emit EvidenceUploaded(ipfsHash, evidences.length - 1);
    }

    function approveEvidence(uint256 index) external onlyContributor {
        require(index < evidences.length, "Invalid index");
        evidences[index].approved = true;
        emit EvidenceApproved(index);
    }

    function getEvidence(uint256 index) external view returns (string memory ipfsHash, uint256 timestamp, bool approved) {
        require(index < evidences.length, "Invalid index");
        Evidence memory e = evidences[index];
        return (e.ipfsHash, e.timestamp, e.approved);
    }

    function getAllEvidences() external view returns (Evidence[] memory) {
        return evidences;
    }
}