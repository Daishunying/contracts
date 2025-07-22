// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint amount) external returns (bool);
    function transfer(address to, uint amount) external returns (bool);
    function balanceOf(address account) external view returns (uint);
}

contract MultiProjectCharity is KeeperCompatibleInterface {
    // 合约创建者
    address public owner;
    // 公共资金池地址
    address public publicPool;

    // 投票模式：一人一票 or 按捐赠加权
    enum VotingMode { OnePersonOneVote, WeightedByDonation }
    // 资金分配模式：按月自动分配 or 截止后一次性分配
    enum DistributionMode { Monthly, FinalAtDeadline }

    // 项目信息结构体
    struct Project {
        address receiver;
        uint256 targetAmount;
        uint256 deadline;
        uint256 received;
        bool finalized;
        bool isETH;
        address tokenAddress;
        VotingMode votingMode;
        uint256 publicPoolRate;
        uint256 voteThresholdPercent;
        DistributionMode distributionMode;
    }

    // 用户捐赠计划结构体
    struct Plan {
        address donor;
        uint projectId;
        uint256 monthlyAmount;
        uint256 minAmount;
        uint256 nextDonationTime;
        bool active;
    }

    // DAO 提案结构体
    struct Proposal {
        string description;
        uint amount;
        address proposer;
        string ipfsEvidence;
        uint yesVotes;
        uint noVotes;
        uint deadline;
        bool executed;
        bool usePublicPool;
        address targetRecipient;
        uint voteThreshold;
        mapping(address => bool) voted; // 防止重复投票
    }

    // 所有项目
    mapping(uint => Project) public projects;
    uint public nextProjectId;

    // 用户捐赠计划
    mapping(address => Plan[]) public userPlans;
    // 用户每个项目的累计捐赠额（用于加权投票）
    mapping(uint => mapping(address => uint)) public donationsByProject;
    // 每个项目的提案数组
    mapping(uint => Proposal[]) public proposals;
    // token => Chainlink价格预言机地址
    mapping(address => AggregatorV3Interface) public priceFeeds;
    // 每个项目的专属资金池
    mapping(uint => uint) public donatePoolBalances;

    // 事件定义
    event ProjectCreated(uint id, address receiver, bool isETH);
    event DonationMade(address donor, uint projectId, uint amount, bool isETH);
    event Received(address sender, uint amount);

    constructor(address _publicPool) {
        owner = msg.sender;
        publicPool = _publicPool;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // 设置价格预言机地址
    function setPriceFeed(address token, address feed) external onlyOwner {
        priceFeeds[token] = AggregatorV3Interface(feed);
    }

    // 查询某 token 折算的美元估值
    function getTokenUSDValue(address token, uint amount) public view returns (uint) {
        AggregatorV3Interface feed = priceFeeds[token];
        require(address(feed) != address(0), "No price feed available");
        (, int price,,,) = feed.latestRoundData();
        require(price > 0, "Invalid price");
        return (amount * uint(price)) / 1e8;
    }

    // 查询 ETH 折算的美元估值
    function getETHUSDValue(uint amount) public view returns (uint) {
        AggregatorV3Interface feed = priceFeeds[address(0)];
        require(address(feed) != address(0), "No ETH price feed");
        (, int price,,,) = feed.latestRoundData();
        require(price > 0, "Invalid price");
        return (amount * uint(price)) / 1e8;
    }

    // 创建项目
    function createProject(
        address receiver,
        uint256 targetAmount,
        uint256 durationDays,
        bool isETH,
        address tokenAddr,
        VotingMode mode,
        uint256 publicPoolRate,
        uint256 voteThresholdPercent,
        DistributionMode distributionMode
    ) external onlyOwner {
        require(receiver != address(0), "Invalid receiver");
        require(publicPoolRate <= 100, "Rate must be <= 100");
        require(voteThresholdPercent <= 100, "Threshold must be <= 100");

        projects[nextProjectId] = Project({
            receiver: receiver,
            targetAmount: targetAmount,
            deadline: block.timestamp + durationDays * 1 days,
            received: 0,
            finalized: false,
            isETH: isETH,
            tokenAddress: tokenAddr,
            votingMode: mode,
            publicPoolRate: publicPoolRate,
            voteThresholdPercent: voteThresholdPercent,
            distributionMode: distributionMode
        });

        emit ProjectCreated(nextProjectId, receiver, isETH);
        nextProjectId++;
    }

    // 执行捐赠计划
    function donateMonthly(uint planIndex) external payable {
        Plan storage plan = userPlans[msg.sender][planIndex];
        require(plan.active, "Inactive plan");

        Project storage proj = projects[plan.projectId];
        require(block.timestamp <= proj.deadline, "Project expired");
        require(block.timestamp >= plan.nextDonationTime, "Too early");

        plan.nextDonationTime += 30 days;
        uint amount = plan.monthlyAmount;
        require(amount >= plan.minAmount, "Below minAmount");

        uint toPublic = (amount * proj.publicPoolRate) / 100;
        uint toDonate = amount - toPublic;

        if (proj.isETH) {
            require(msg.value >= amount, "Insufficient ETH");
            payable(publicPool).transfer(toPublic);
            donatePoolBalances[plan.projectId] += toDonate;
            emit DonationMade(msg.sender, plan.projectId, getETHUSDValue(amount), true);
        } else {
            IERC20 token = IERC20(proj.tokenAddress);
            require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
            require(token.transfer(publicPool, toPublic), "PublicPool transfer failed");
            donatePoolBalances[plan.projectId] += toDonate;
            emit DonationMade(msg.sender, plan.projectId, getTokenUSDValue(proj.tokenAddress, amount), false);
        }

        proj.received += amount;
        donationsByProject[plan.projectId][msg.sender] += amount;
    }

    // Keeper check 函数：是否需要 finalize 项目
    function checkUpkeep(bytes calldata /*checkData*/) external override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = false;
        performData = "";

        for (uint i = 0; i < nextProjectId; i++) {
            if (!projects[i].finalized && block.timestamp > projects[i].deadline) {
                upkeepNeeded = true;
                performData = abi.encode(i);
                break;
            }
        }

        return (upkeepNeeded, performData);
    }

    // Keeper 执行函数：完成 finalize
    function performUpkeep(bytes calldata performData) external override {
        uint projectId = abi.decode(performData, (uint));
        finalizeProject(projectId);
    }

    // 项目结束（可扩展分配逻辑）
    function finalizeProject(uint projectId) public {
        Project storage proj = projects[projectId];
        require(!proj.finalized, "Already finalized");
        require(block.timestamp > proj.deadline, "Too early");

        proj.finalized = true;
        // 可扩展分配逻辑
    }

    // fallback 接收 ETH
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}