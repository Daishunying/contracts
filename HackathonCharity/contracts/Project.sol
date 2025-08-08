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
        require(msg.value >= minimumContribution, "Contribution amount is too low");

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

    // 1) 关闭投票（阈值=0）→ 直接通过
    if (voteThreshold == 0) {
        request.reciptent.transfer(request.amount);
        request.isCompleted = true;
        return;
    }

    // 2) 计算阈值基数
    uint256 base = (votingMode == VotingMode.WeightedByAmount)
        ? raisedAmount
        : noOfContributors;
    uint256 threshold = (base * voteThreshold) / 100;

    // 3) 达到阈值 → 立刻通过（不需要等到 voteDeadline）
    if (request.voteWeight >= threshold) {
        request.reciptent.transfer(request.amount);
        request.isCompleted = true;
        return;
    }

    // 4) 未达阈值 → 仅当“无人投票 + 开启默认通过 + 已到期”才放行
    if (defaultApproveIfNoVote) {
        require(block.timestamp > request.voteDeadline, "Voting still active");
        require(request.voteWeight == 0, "Votes present");
        request.reciptent.transfer(request.amount);
        request.isCompleted = true;
        return;
    }

    // 5) 其他情况：不满足
    revert("Not enough approvals");
}

    function markExpired() public {
        require(block.timestamp > deadline, "Deadline not reached");
        require(state == State.Fundraising, "Already closed");
        state = State.Expired;
    }

function getSummary()
  external
  view
  returns (
    address _creator,
    uint256 _minimumContribution,
    uint256 _deadline,
    uint256 _targetContribution,
    uint256 _raisedAmount,
    uint256 _noOfContributors,
    uint8   _state,
    uint256 _voteThreshold,
    bool    _defaultApproveIfNoVote
  )
{
  return (
    creator,
    minimumContribution,
    deadline,
    targetContribution,
    raisedAmount,
    noOfContributors,
    uint8(state),
    voteThreshold,
    defaultApproveIfNoVote
  );
}
}
