// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrowdVaultVulnerable} from "../src/vulnerable/CrowdVaultVulnerable.sol";
import {CrowdVaultSecure} from "../src/secure/CrowdVaultSecure.sol";

interface VmScript {
    function envUint(string calldata name) external returns (uint256 value);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

/// @notice Deploys both teaching variants to the local Anvil node.
contract DeployLocal {
    VmScript private constant vm = VmScript(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external {
        uint256 localKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(localKey);
        new CrowdVaultVulnerable();
        new CrowdVaultSecure();
        vm.stopBroadcast();
    }
}
