// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Project.sol";

contract ProjectManager {
    address public owner;
    Project[] public projects;

    event ProjectCreated(address indexed projectAddress, address indexed creator);

    constructor() {
        owner = msg.sender;
    }
    function createProject(
        uint256 minimumContribution,
        uint256 deadlineDuration,
        uint256 targetContribution,
        uint256 voteThreshold,
        bool defaultApproveIfNoVote,
        Project.VotingMode votingMode
    ) external {
        Project newProject = new Project(
            minimumContribution,
            deadlineDuration,
            targetContribution,
            voteThreshold,
            defaultApproveIfNoVote,
            votingMode
        );
        projects.push(newProject);
        emit ProjectCreated(address(newProject), msg.sender);
    }

    function getProjects() external view returns (Project[] memory) {
        return projects;
    }

    function getProjectAddress(uint index) external view returns (address) {
        require(index < projects.length, "Index out of range");
        return address(projects[index]);
    }

    function totalProjects() external view returns (uint256) {
        return projects.length;
    }
}