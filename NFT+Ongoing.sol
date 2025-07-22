// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint amount) external returns (bool);
    function transfer(address to, uint amount) external returns (bool);
    function balanceOf(address account) external view returns (uint);
}

interface IDonationCertificateNFT {
    function mintCreatorCertificate(address to, uint projectId) external;
    function mintDonorCertificate(address to, uint projectId, uint tier) external;
}

contract MultiProjectCharity is KeeperCompatibleInterface {
    address public owner;
    address public publicPool;
    IDonationCertificateNFT public nft;

    enum VotingMode { OnePersonOneVote, WeightedByDonation }
    enum DistributionMode { Monthly, FinalAtDeadline }

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

    struct Plan {
        address donor;
        uint projectId;
        uint256 monthlyAmount;
        uint256 minAmount;
        uint256 nextDonationTime;
        bool active;
    }

    mapping(uint => Project) public projects;
    uint public nextProjectId;

    mapping(address => Plan[]) public userPlans;
    mapping(uint => mapping(address => uint)) public donationsByProject;
    mapping(address => AggregatorV3Interface) public priceFeeds;
    mapping(uint => uint) public donatePoolBalances;
    mapping(address => mapping(uint => bool)) public donorRewardedTier1;
    mapping(address => mapping(uint => bool)) public donorRewardedTier2;
    mapping(address => mapping(uint => bool)) public donorRewardedTier3;

    event ProjectCreated(uint id, address receiver, bool isETH);
    event DonationMade(address donor, uint projectId, uint amount, bool isETH);
    event Received(address sender, uint amount);

    constructor(address _publicPool, address _nft) {
        owner = msg.sender;
        publicPool = _publicPool;
        nft = IDonationCertificateNFT(_nft);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function setPriceFeed(address token, address feed) external onlyOwner {
        priceFeeds[token] = AggregatorV3Interface(feed);
    }

    function getTokenUSDValue(address token, uint amount) public view returns (uint) {
        AggregatorV3Interface feed = priceFeeds[token];
        require(address(feed) != address(0), "No price feed available");
        (, int price,,,) = feed.latestRoundData();
        require(price > 0, "Invalid price");
        return (amount * uint(price)) / 1e8;
    }

    function getETHUSDValue(uint amount) public view returns (uint) {
        AggregatorV3Interface feed = priceFeeds[address(0)];
        require(address(feed) != address(0), "No ETH price feed");
        (, int price,,,) = feed.latestRoundData();
        require(price > 0, "Invalid price");
        return (amount * uint(price)) / 1e8;
    }

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

        nft.mintCreatorCertificate(receiver, nextProjectId);

        emit ProjectCreated(nextProjectId, receiver, isETH);
        nextProjectId++;
    }

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

        uint usdAmount;
        if (proj.isETH) {
            require(msg.value >= amount, "Insufficient ETH");
            payable(publicPool).transfer(toPublic);
            donatePoolBalances[plan.projectId] += toDonate;
            usdAmount = getETHUSDValue(amount);
            emit DonationMade(msg.sender, plan.projectId, usdAmount, true);
        } else {
            IERC20 token = IERC20(proj.tokenAddress);
            require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
            require(token.transfer(publicPool, toPublic), "PublicPool transfer failed");
            donatePoolBalances[plan.projectId] += toDonate;
            usdAmount = getTokenUSDValue(proj.tokenAddress, amount);
            emit DonationMade(msg.sender, plan.projectId, usdAmount, false);
        }

        proj.received += amount;
        donationsByProject[plan.projectId][msg.sender] += usdAmount;

        if (usdAmount >= 10000 && !donorRewardedTier3[msg.sender][plan.projectId]) {
            nft.mintDonorCertificate(msg.sender, plan.projectId, 3);
            donorRewardedTier3[msg.sender][plan.projectId] = true;
        } else if (usdAmount >= 5000 && !donorRewardedTier2[msg.sender][plan.projectId]) {
            nft.mintDonorCertificate(msg.sender, plan.projectId, 2);
            donorRewardedTier2[msg.sender][plan.projectId] = true;
        } else if (usdAmount >= 500 && !donorRewardedTier1[msg.sender][plan.projectId]) {
            nft.mintDonorCertificate(msg.sender, plan.projectId, 1);
            donorRewardedTier1[msg.sender][plan.projectId] = true;
        }
    }

    function checkUpkeep(bytes calldata) external override returns (bool upkeepNeeded, bytes memory performData) {
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

    function performUpkeep(bytes calldata performData) external override {
        uint projectId = abi.decode(performData, (uint));
        finalizeProject(projectId);
    }

    function finalizeProject(uint projectId) public {
        Project storage proj = projects[projectId];
        require(!proj.finalized, "Already finalized");
        require(block.timestamp > proj.deadline, "Too early");

        proj.finalized = true;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
