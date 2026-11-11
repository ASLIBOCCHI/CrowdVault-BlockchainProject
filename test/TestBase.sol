// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface Vm {
    function deal(address account, uint256 newBalance) external;
    function expectPartialRevert(bytes4 revertData) external;
    function prank(address caller) external;
    function warp(uint256 newTimestamp) external;
}

/// @dev Small local test helper so the project has no external test dependency.
abstract contract TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    error AssertionFailedUint(uint256 actual, uint256 expected);

    function assertEq(uint256 actual, uint256 expected) internal pure {
        if (actual != expected) revert AssertionFailedUint(actual, expected);
    }

    function assertEq(address actual, address expected) internal pure {
        require(actual == expected, "assertEq(address)");
    }

    function assertEq(bool actual, bool expected) internal pure {
        require(actual == expected, "assertEq(bool)");
    }

    function assertEq(bytes32 actual, bytes32 expected) internal pure {
        require(actual == expected, "assertEq(bytes32)");
    }

    function assertTrue(bool value) internal pure {
        require(value, "assertTrue");
    }
}
