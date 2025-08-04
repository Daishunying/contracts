// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

contract Project {
    enum State {
        Fundraising,
        Expired,
        Successful
    }
    enum VotingMode {
        OnePersonOneVote,
        WeightedByAmount
    }

    struct WithdrawRequest {
        string description;
        uint256 amount;
        uint256 voteWeight;
        uint256 noOfVotes;
        mapping(address => bool) voters;
        bool isCompleted;
        address payable reciptent;
        uint256 voteDeadline;
        uint256 createdAt;
    }

    address payable public creator;
    uint256 public minimumContribution;
    uint256 public deadline;
    uint256 public targetContribution;
    uint public raisedAmount;
    uint public noOfContributors;
    uint256 public numOfWithdrawRequests = 0;
    State public state = State.Fundraising;

    uint256 public voteThreshold; // 0 = no DAO, 1-99 = approval ratio
    bool public defaultApproveIfNoVote = true;
    VotingMode public votingMode;

    mapping(address => uint256) public contributors;
    mapping(uint256 => WithdrawRequest) public withdrawRequests;

    modifier onlyCreator() {
        require(msg.sender == creator, "Only creator can call this.");
        _;
    }

    modifier onlyContributor() {
        require(contributors[msg.sender] > 0, "Only contributor can call this.");
        _;
    }

    constructor(
        uint256 _minimumContribution,
        uint256 _deadline,
        uint256 _targetContribution,
        uint256 _voteThreshold,
        bool _defaultApproveIfNoVote,
        VotingMode _votingMode
    ) {
        minimumContribution = _minimumContribution;
        deadline = block.timestamp + _deadline;
        targetContribution = _targetContribution;
        voteThreshold = _voteThreshold;
        defaultApproveIfNoVote = _defaultApproveIfNoVote;
        votingMode = _votingMode;
        creator = payable(msg.sender);
    }

    function contribute() public payable {
        require(state == State.Fundraising, "Not fundraising");
        require(msg.value >= minimumContribution, "Amount below minimum");

        if (contributors[msg.sender] == 0) {
            noOfContributors++;
        }

        contributors[msg.sender] += msg.value;
        raisedAmount += msg.value;

        if (raisedAmount >= targetContribution) {
            state = State.Successful;
        }
    }

    function refund() public onlyContributor {
        require(state == State.Expired, "Not expired");
        uint256 value = contributors[msg.sender];
        require(value > 0, "Nothing to refund");

        contributors[msg.sender] = 0;
        payable(msg.sender).transfer(value);
    }

    function createWithdrawRequest(string memory desc, uint256 amount, address payable recipient, uint256 voteDuration) public onlyCreator {
        WithdrawRequest storage request = withdrawRequests[numOfWithdrawRequests++];
        request.description = desc;
        request.amount = amount;
        request.reciptent = recipient;
        request.isCompleted = false;
        request.createdAt = block.timestamp;
        request.voteDeadline = block.timestamp + voteDuration;
    }

    function voteWithdrawRequest(uint256 index) public onlyContributor {
        require(index < numOfWithdrawRequests, "Invalid index");
        WithdrawRequest storage request = withdrawRequests[index];
        require(block.timestamp <= request.voteDeadline, "Voting ended");
        require(!request.voters[msg.sender], "Already voted");

        request.voters[msg.sender] = true;
        uint256 weight = votingMode == VotingMode.WeightedByAmount ? contributors[msg.sender] : 1;
        request.voteWeight += weight;
    }

    function finalizeWithdrawRequest(uint256 index) public onlyCreator {
        require(index < numOfWithdrawRequests, "Invalid index");
        WithdrawRequest storage request = withdrawRequests[index];
        require(!request.isCompleted, "Already completed");
        
        if (voteThreshold == 0) {
            // DAO disabled: creator can withdraw directly
            request.reciptent.transfer(request.amount);
            request.isCompleted = true;
            return;
        }

        require(block.timestamp > request.voteDeadline, "Voting still active");

        // Approval two modes: raisedAmount weight, contributors; default =true, all no vote seems as agree
        uint256 voteBase = votingMode == VotingMode.WeightedByAmount
            ? (defaultApproveIfNoVote ? raisedAmount : request.voteWeight)
            : (defaultApproveIfNoVote ? noOfContributors : request.voteWeight);

        uint256 threshold = voteBase * voteThreshold / 100;
        require(request.voteWeight >= threshold, "Not enough approvals");

        request.reciptent.transfer(request.amount);
        request.isCompleted = true;
    }

    function markExpired() public {
        require(block.timestamp > deadline, "Deadline not reached");
        require(state == State.Fundraising, "Already closed");
        state = State.Expired;
    }

    function getProjectSummary() public view returns (
        address, uint256, uint256, uint256, uint256, uint256, State, uint256, bool
    ) {
        return (
            creator,
            minimumContribution,
            deadline,
            targetContribution,
            raisedAmount,
            noOfContributors,
            state,
            voteThreshold,
            defaultApproveIfNoVote
        );
    }
}
