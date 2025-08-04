// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import './Project.sol';

contract Oneoff {

    event ProjectStarted(
        address projectContractAddress,
        address creator,
        uint256 minContribution,
        uint256 projectDeadline,
        uint256 goalAmount,
        uint256 currentAmount,
        uint256 noOfContributors,
        string title,
        string desc,
        uint256 currentState
    );

    event ContributionReceived(
        address projectAddress,
        uint256 contributedAmount,
        address indexed contributor
    );

    Project[] private projects;

    // Create a new crowdfunding project
    function createProject(
        uint256 minimumContribution,
        uint256 deadline,
        uint256 targetContribution,
        uint256 voteThreshold,
        bool defaultApproveIfNoVote,
        Project.VotingMode votingMode,
        string memory projectTitle,
        string memory projectDesc
    ) public {
        Project newProject = new Project(
            minimumContribution,
            deadline,
            targetContribution,
            voteThreshold,
            defaultApproveIfNoVote,
            votingMode
        );

        projects.push(Project(newProject));

        emit ProjectStarted(
            address(newProject),
            msg.sender,
            minimumContribution,
            deadline,
            targetContribution,
            0,
            0,
            projectTitle,
            projectDesc,
            0
        );
    }


    // Return all created projects
    function returnAllProjects() external view returns (Project[] memory) {
        return projects;
    }

    // Allow user to contribute to a specific project
    function contribute(address _projectAddress) public payable {
        uint256 minContributionAmount = Project(_projectAddress).minimumContribution();
        Project.State projectState = Project(_projectAddress).state();

        require(projectState == Project.State.Fundraising, 'Invalid state');
        require(msg.value >= minContributionAmount, 'Contribution amount is too low!');

        Project(_projectAddress).contribute{value: msg.value}();
        emit ContributionReceived(_projectAddress, msg.value, msg.sender);
    }
}
