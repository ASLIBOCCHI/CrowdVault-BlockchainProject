// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrowdVaultBase} from "../src/CrowdVaultBase.sol";
import {CrowdVaultVulnerable} from "../src/vulnerable/CrowdVaultVulnerable.sol";
import {CrowdVaultSecure} from "../src/secure/CrowdVaultSecure.sol";
import {UnauthorizedWithdrawExploit} from "../src/exploits/UnauthorizedWithdrawExploit.sol";
import {ReentrancyExploit} from "../src/exploits/ReentrancyExploit.sol";
import {TestBase} from "./TestBase.sol";

contract CrowdVaultTest is TestBase {
    address private constant CREATOR = address(0xA11CE);
    address private constant CONTRIBUTOR = address(0xB0B);
    address private constant HONEST_CONTRIBUTOR = address(0xCAFE);
    address private constant ATTACKER = address(0xBAD);
    uint256 private constant DURATION = 1 days;

    function testCreateCampaignAndReadDetails() public {
        CrowdVaultSecure vault = new CrowdVaultSecure();
        uint256 id = _create(vault, "Neighborhood library", 3 ether, CREATOR);
        (CrowdVaultBase.Campaign memory details, CrowdVaultBase.CampaignStatus status) =
            vault.getCampaign(id);

        assertEq(id, 0);
        assertEq(keccak256(bytes(details.title)), keccak256(bytes("Neighborhood library")));
        assertEq(details.creator, CREATOR);
        assertEq(details.target, 3 ether);
        assertEq(details.deadline, block.timestamp + DURATION);
        assertEq(uint256(status), uint256(CrowdVaultBase.CampaignStatus.Active));
    }

    function testMultipleCampaignsKeepTheirContributionBalancesSeparate() public {
        CrowdVaultSecure vault = new CrowdVaultSecure();
        uint256 first = _create(vault, "First", 3 ether, CREATOR);
        uint256 second = _create(vault, "Second", 4 ether, CONTRIBUTOR);

        _contribute(vault, first, CONTRIBUTOR, 1 ether);
        _contribute(vault, second, CONTRIBUTOR, 2 ether);

        (CrowdVaultBase.Campaign memory firstDetails,) = vault.getCampaign(first);
        (CrowdVaultBase.Campaign memory secondDetails,) = vault.getCampaign(second);
        assertEq(vault.campaignCount(), 2);
        assertEq(firstDetails.totalRaised, 1 ether);
        assertEq(secondDetails.totalRaised, 2 ether);
        assertEq(vault.contributions(first, CONTRIBUTOR), 1 ether);
        assertEq(vault.contributions(second, CONTRIBUTOR), 2 ether);
    }

    function testSecureCreatorWithdrawsAfterSuccessfulCampaign() public {
        CrowdVaultSecure vault = new CrowdVaultSecure();
        uint256 id = _create(vault, "Target reached", 2 ether, CREATOR);
        _contribute(vault, id, CONTRIBUTOR, 2 ether);
        vm.warp(block.timestamp + DURATION + 1);
        uint256 creatorBalanceBefore = CREATOR.balance;

        vm.prank(CREATOR);
        vault.withdrawFunds(id);

        (CrowdVaultBase.Campaign memory details, CrowdVaultBase.CampaignStatus status) =
            vault.getCampaign(id);
        assertEq(CREATOR.balance, creatorBalanceBefore + 2 ether);
        assertEq(address(vault).balance, 0);
        assertEq(details.withdrawn, true);
        assertEq(uint256(status), uint256(CrowdVaultBase.CampaignStatus.Withdrawn));
    }

    function testVulnerableWithdrawLetsUnauthorizedCallerTakeFunds() public {
        CrowdVaultVulnerable vault = new CrowdVaultVulnerable();
        uint256 id = _create(vault, "Unauthorized payout", 2 ether, CREATOR);
        _contribute(vault, id, CONTRIBUTOR, 2 ether);
        vm.warp(block.timestamp + DURATION + 1);
        UnauthorizedWithdrawExploit exploit = new UnauthorizedWithdrawExploit(address(vault));

        exploit.attack(id);

        assertEq(address(exploit).balance, 2 ether);
        assertEq(address(vault).balance, 0);
    }

    function testSecureWithdrawRejectsUnauthorizedCaller() public {
        CrowdVaultSecure vault = new CrowdVaultSecure();
        uint256 id = _create(vault, "Protected payout", 2 ether, CREATOR);
        _contribute(vault, id, CONTRIBUTOR, 2 ether);
        vm.warp(block.timestamp + DURATION + 1);
        UnauthorizedWithdrawExploit exploit = new UnauthorizedWithdrawExploit(address(vault));

        vm.expectPartialRevert(CrowdVaultBase.NotCampaignCreator.selector);
        exploit.attack(id);

        assertEq(address(exploit).balance, 0);
        assertEq(address(vault).balance, 2 ether);
    }

    function testVulnerableRefundCanBeReentered() public {
        CrowdVaultVulnerable vault = new CrowdVaultVulnerable();
        uint256 id = _create(vault, "Failed campaign", 10 ether, CREATOR);
        ReentrancyExploit exploit = new ReentrancyExploit(address(vault));
        exploit.contribute{value: 1 ether}(id);
        _contribute(vault, id, HONEST_CONTRIBUTOR, 5 ether);
        vm.warp(block.timestamp + DURATION + 1);

        exploit.attack(id, 4);

        assertEq(exploit.reentries(), 4);
        assertEq(address(exploit).balance, 5 ether);
        assertEq(address(vault).balance, 1 ether);
        assertEq(vault.contributions(id, address(exploit)), 0);
    }

    function testSecureRefundBlocksReentrancyAndPaysOnlyOnce() public {
        CrowdVaultSecure vault = new CrowdVaultSecure();
        uint256 id = _create(vault, "Failed campaign", 10 ether, CREATOR);
        ReentrancyExploit exploit = new ReentrancyExploit(address(vault));
        exploit.contribute{value: 1 ether}(id);
        _contribute(vault, id, HONEST_CONTRIBUTOR, 5 ether);
        vm.warp(block.timestamp + DURATION + 1);

        exploit.attack(id, 4);

        assertEq(exploit.reentries(), 1);
        assertEq(exploit.reentryBlocked(), true);
        assertEq(address(exploit).balance, 1 ether);
        assertEq(address(vault).balance, 5 ether);
        assertEq(vault.contributions(id, address(exploit)), 0);
    }

    function testSecureContributorCanRefundFailedCampaign() public {
        CrowdVaultSecure vault = new CrowdVaultSecure();
        uint256 id = _create(vault, "Refund campaign", 5 ether, CREATOR);
        _contribute(vault, id, CONTRIBUTOR, 2 ether);
        vm.warp(block.timestamp + DURATION + 1);
        uint256 balanceBefore = CONTRIBUTOR.balance;

        vm.prank(CONTRIBUTOR);
        vault.refund(id);

        assertEq(CONTRIBUTOR.balance, balanceBefore + 2 ether);
        assertEq(vault.contributions(id, CONTRIBUTOR), 0);
        assertEq(address(vault).balance, 0);
    }

    function testRefundIsUnavailableUntilCampaignDeadline() public {
        CrowdVaultSecure vault = new CrowdVaultSecure();
        uint256 id = _create(vault, "Still active", 5 ether, CREATOR);
        _contribute(vault, id, CONTRIBUTOR, 2 ether);

        vm.expectPartialRevert(CrowdVaultBase.CampaignStillActive.selector);
        vm.prank(CONTRIBUTOR);
        vault.refund(id);
    }

    function _create(CrowdVaultBase vault, string memory title, uint256 target, address creator)
        private
        returns (uint256 id)
    {
        vm.prank(creator);
        id = vault.createCampaign(title, target, DURATION);
    }

    function _contribute(
        CrowdVaultBase vault,
        uint256 campaignId,
        address contributor,
        uint256 amount
    ) private {
        vm.deal(contributor, amount);
        vm.prank(contributor);
        vault.contribute{value: amount}(campaignId);
    }
}
