# CrowdVault

CrowdVault is a multi-campaign Ethereum crowdfunding example based on the group's proposal. Each campaign has a title, ETH target, and duration. Contributors can fund it before the deadline. After the deadline, the creator can withdraw if the target was reached; contributors can claim refunds if it failed.

This repository contains two implementations for a local security demonstration:

- `CrowdVaultVulnerable` intentionally omits the creator check in `withdrawFunds` and updates a contributor's balance after the ETH call in `refund`.
- `CrowdVaultSecure` checks creator authorization and applies checks-effects-interactions plus a reentrancy guard to withdrawals and refunds.

**Use `CrowdVaultVulnerable` only on a local Anvil node or in tests. Never deploy it to a public or value-bearing network.**

## Requirements

- Foundry (`forge`, `cast`, and `anvil`)

The tests use a small local cheatcode/assertion helper, so no external Solidity test library is needed.

## Build and test

```sh
forge build
forge test -vv
```

The tests cover campaign creation and reads, multiple campaign accounting, successful creator withdrawal, failed campaign refunds, the unauthorized withdrawal exploit, the refund reentrancy exploit, and the corresponding secure behavior.

To see the attack traces:

```sh
forge test --match-test testVulnerableWithdrawLetsUnauthorizedCallerTakeFunds -vvvv
forge test --match-test testVulnerableRefundCanBeReentered -vvvv
forge test --match-test testSecureWithdrawRejectsUnauthorizedCaller -vvvv
forge test --match-test testSecureRefundBlocksReentrancyAndPaysOnlyOnce -vvvv
```

## Local Anvil deployment

In terminal 1, start a local chain:

```sh
anvil
```

In terminal 2, deploy both variants using Anvil's first pre-funded account:

```sh
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 forge script script/DeployLocal.s.sol:DeployLocal --broadcast --rpc-url http://127.0.0.1:8545
```

Anvil prints this publicly known test key when it starts. Never use it on a public network. The script has no public RPC setting and sends transactions only to the local URL shown above.

To exercise the deployed contracts manually, read the `contractAddress` values for the `CREATE` transactions in `broadcast/DeployLocal.s.sol/31337/run-latest.json` and use Anvil account 0 as the creator. For example, create a one-ETH campaign and contribute to campaign `0`:

```sh
cast send <CONTRACT_ADDRESS> "createCampaign(string,uint256,uint256)" "Local demo" 1000000000000000000 3600 --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
cast send <CONTRACT_ADDRESS> "contribute(uint256)" 0 --value 1000000000000000000 --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

Wait for the campaign deadline before withdrawing. The secure contract pays only its creator. The vulnerable contract pays whoever calls `withdrawFunds`, which the test exploit demonstrates without needing a public chain.

For the refund reentrancy demo, run the focused vulnerable and secure tests above. They deploy the exploit contract, seed a failed campaign with honest funds, and show the vulnerable version paying the attacker 5 ETH from a 1 ETH contribution while the secure version returns only 1 ETH and leaves the honest contributor's 5 ETH intact.

## Contract interface

- `createCampaign(string title, uint256 target, uint256 duration)` creates a campaign and returns its zero-based ID.
- `contribute(uint256 campaignId)` accepts the contribution as `msg.value`.
- `withdrawFunds(uint256 campaignId)` transfers funds after a successful campaign deadline.
- `refund(uint256 campaignId)` returns the caller's contribution after a failed campaign deadline.
- `getCampaign(uint256 campaignId)` returns the campaign details and its current status.

Individual contribution balances are available through `contributions(campaignId, contributor)`.
