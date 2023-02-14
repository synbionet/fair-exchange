// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetFunds.sol";
import "../src/BionetRouter.sol";
import "../src/BionetExchange.sol";
import "../src/BionetVoucher.sol";

import "forge-std/Script.sol";
import "forge-std/console2.sol";

/**
 * Deploy contracts to local Anvil.  Owner is Anvil account 0
 */
contract AnvilDeployScript is Script {
    uint256 constant OWNER_PRIV_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    address owner;
    address router;
    address funds;
    address voucher;
    address exchange;

    function setUp() public {
        owner = vm.addr(OWNER_PRIV_KEY);
        uint256 ownerNonce = vm.getNonce(owner);

        console.log("owner: %s (anvil account 0)", owner);
        console.log("owner starting nonce: %d", ownerNonce);

        // Precalculate contract addresses based on the deployer (owner)
        // this makes setup below easier

        // router
        router = computeCreateAddress(owner, ownerNonce);
        // funds
        funds = computeCreateAddress(owner, ownerNonce + 1);
        // voucher
        voucher = computeCreateAddress(owner, ownerNonce + 2);
        // exchange
        exchange = computeCreateAddress(owner, ownerNonce + 3);
    }

    function run() public {
        // Deploy the contracts:
        // Make sure to deploy them in the same order as they were calculated above
        vm.startBroadcast(OWNER_PRIV_KEY);

        new BionetRouter(funds, exchange);
        new BionetFunds(router, exchange);
        new BionetVoucher(router, exchange);
        new BionetExchange(router, funds, voucher);

        vm.stopBroadcast();

        console.log("~~ deployed to local Anvil~~");
        console.log("router:   %s", router);
        console.log("funds:    %s", funds);
        console.log("voucher:  %s", voucher);
        console.log("exchange: %s", exchange);
    }
}
