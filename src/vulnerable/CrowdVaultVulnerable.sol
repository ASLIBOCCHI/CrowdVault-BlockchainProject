// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrowdVaultBase} from "../CrowdVaultBase.sol";

/// @notice Educational-only contract with the two proposal vulnerabilities.
/// @dev Never deploy this contract to a public or value-bearing network.
contract CrowdVaultVulnerable is CrowdVaultBase {
    function withdrawFunds(uint256 campaignId) external override {
        Campaign storage campaign = _campaignAt(campaignId);
        _requireSuccessful(campaign, campaignId);
        if (campaign.withdrawn) revert FundsAlreadyWithdrawn(campaignId);

        // Intentionally missing: msg.sender == campaign.creator.
        // The caller becomes the recipient, so any account can take the payout.
        campaign.withdrawn = true;
        uint256 amount = campaign.totalRaised;
        emit FundsWithdrawn(campaignId, msg.sender, amount);
        _sendEth(payable(msg.sender), amount);
    }

    function refund(uint256 campaignId) external override {
        Campaign storage campaign = _campaignAt(campaignId);
        _requireFailed(campaign, campaignId);

        uint256 amount = contributions[campaignId][msg.sender];
        if (amount == 0) revert NoContribution(campaignId, msg.sender);

        // Intentionally vulnerable: the external call happens before the balance update.
        emit RefundIssued(campaignId, msg.sender, amount);
        _sendEth(payable(msg.sender), amount);
        contributions[campaignId][msg.sender] = 0;
    }
}
