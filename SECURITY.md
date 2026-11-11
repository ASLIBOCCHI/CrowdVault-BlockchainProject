# Security demonstration scope

`src/vulnerable/CrowdVaultVulnerable.sol` is intentionally insecure for the course demonstration. It has two deliberate flaws:

1. `withdrawFunds` does not verify that `msg.sender` is the campaign creator and pays the caller.
2. `refund` sends ETH before clearing the caller's contribution balance, allowing a reentrant receiver to claim the same balance repeatedly.

The exploit contracts and tests run entirely in Foundry's local EVM. Do not deploy the vulnerable implementation to a public network or use it to hold real funds. Use `CrowdVaultSecure` for the patched comparison.
