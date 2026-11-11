// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract CrowdVaultBase {
    enum CampaignStatus {
        Active,
        Successful,
        Failed,
        Withdrawn
    }

    struct Campaign {
        string title;
        address creator;
        uint256 target;
        uint256 deadline;
        uint256 totalRaised;
        bool withdrawn;
    }

    error InvalidCampaignId(uint256 campaignId);
    error EmptyTitle();
    error InvalidTarget();
    error InvalidDuration();
    error CampaignEnded(uint256 campaignId);
    error ZeroContribution();
    error CampaignStillActive(uint256 campaignId);
    error TargetNotReached(uint256 campaignId);
    error CampaignFailed(uint256 campaignId);
    error FundsAlreadyWithdrawn(uint256 campaignId);
    error NotCampaignCreator(uint256 campaignId, address caller);
    error NoContribution(uint256 campaignId, address contributor);
    error TransferFailed(address recipient, uint256 amount);
    error ReentrantCall();

    uint256 public campaignCount;
    mapping(uint256 campaignId => Campaign campaign) internal _campaigns;
    mapping(uint256 campaignId => mapping(address contributor => uint256 amount)) public contributions;

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 target,
        uint256 deadline
    );
    event ContributionReceived(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event FundsWithdrawn(uint256 indexed campaignId, address indexed recipient, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    function createCampaign(string calldata title, uint256 target, uint256 duration)
        external
        returns (uint256 campaignId)
    {
        if (bytes(title).length == 0) revert EmptyTitle();
        if (target == 0) revert InvalidTarget();
        if (duration == 0) revert InvalidDuration();

        campaignId = campaignCount++;
        uint256 deadline = block.timestamp + duration;
        _campaigns[campaignId] = Campaign({
            title: title,
            creator: msg.sender,
            target: target,
            deadline: deadline,
            totalRaised: 0,
            withdrawn: false
        });

        emit CampaignCreated(campaignId, msg.sender, title, target, deadline);
    }

    function contribute(uint256 campaignId) external payable {
        Campaign storage campaign = _campaignAt(campaignId);
        if (block.timestamp >= campaign.deadline) revert CampaignEnded(campaignId);
        if (campaign.withdrawn) revert FundsAlreadyWithdrawn(campaignId);
        if (msg.value == 0) revert ZeroContribution();

        campaign.totalRaised += msg.value;
        contributions[campaignId][msg.sender] += msg.value;

        emit ContributionReceived(campaignId, msg.sender, msg.value);
    }

    function getCampaign(uint256 campaignId)
        external
        view
        returns (Campaign memory campaign, CampaignStatus status)
    {
        campaign = _campaignAt(campaignId);
        status = _statusOf(campaign);
    }

    function withdrawFunds(uint256 campaignId) external virtual;

    function refund(uint256 campaignId) external virtual;

    function _campaignAt(uint256 campaignId) internal view returns (Campaign storage campaign) {
        if (campaignId >= campaignCount) revert InvalidCampaignId(campaignId);
        campaign = _campaigns[campaignId];
    }

    function _requireSuccessful(Campaign storage campaign, uint256 campaignId) internal view {
        if (block.timestamp < campaign.deadline) revert CampaignStillActive(campaignId);
        if (campaign.totalRaised < campaign.target) revert TargetNotReached(campaignId);
    }

    function _requireFailed(Campaign storage campaign, uint256 campaignId) internal view {
        if (block.timestamp < campaign.deadline) revert CampaignStillActive(campaignId);
        if (campaign.totalRaised >= campaign.target) revert CampaignFailed(campaignId);
    }

    function _statusOf(Campaign memory campaign) internal view returns (CampaignStatus) {
        if (campaign.withdrawn) return CampaignStatus.Withdrawn;
        if (block.timestamp < campaign.deadline) return CampaignStatus.Active;
        if (campaign.totalRaised >= campaign.target) return CampaignStatus.Successful;
        return CampaignStatus.Failed;
    }

    function _sendEth(address payable recipient, uint256 amount) internal {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed(recipient, amount);
    }
}
