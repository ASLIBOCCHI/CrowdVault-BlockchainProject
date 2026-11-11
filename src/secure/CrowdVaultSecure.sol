// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrowdVaultBase} from "../CrowdVaultBase.sol";

/// @notice CrowdVault with creator authorization and reentrancy-safe refunds.
contract CrowdVaultSecure is CrowdVaultBase {
    uint256 private _lock = 1;

    modifier nonReentrant() {
        if (_lock != 1) revert ReentrantCall();
        _lock = 2;
        _;
        _lock = 1;
    }

    function withdrawFunds(uint256 campaignId) external override nonReentrant {
        Campaign storage campaign = _campaignAt(campaignId);
        if (msg.sender != campaign.creator) revert NotCampaignCreator(campaignId, msg.sender);
        _requireSuccessful(campaign, campaignId);
        if (campaign.withdrawn) revert FundsAlreadyWithdrawn(campaignId);

        campaign.withdrawn = true;
        uint256 amount = campaign.totalRaised;
        emit FundsWithdrawn(campaignId, campaign.creator, amount);
        _sendEth(payable(campaign.creator), amount);
    }

    function refund(uint256 campaignId) external override nonReentrant {
        Campaign storage campaign = _campaignAt(campaignId);
        _requireFailed(campaign, campaignId);

        uint256 amount = contributions[campaignId][msg.sender];
        if (amount == 0) revert NoContribution(campaignId, msg.sender);

        // Effects happen before the external call; a failed transfer reverts the state change.
        contributions[campaignId][msg.sender] = 0;
        emit RefundIssued(campaignId, msg.sender, amount);
        _sendEth(payable(msg.sender), amount);
    }
}
