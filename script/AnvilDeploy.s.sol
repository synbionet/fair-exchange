// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

/*
import "../src/BionetRouter.sol";
import "../src/BionetExchange.sol";
import "../src/BionetVoucher.sol";
*/

import "forge-std/Script.sol";
import "forge-std/console2.sol";

/**
 * Deploy contracts to local Anvil.  Owner is Anvil account 0
 */
contract AnvilDeployScript is Script {
    uint256 constant OWNER_PRIV_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() public {
        /*
        vm.startBroadcast(OWNER_PRIV_KEY);

        // Deploy contracts
        BionetRouter router = new BionetRouter();
        BionetVoucher voucher = new BionetVoucher();
        BionetExchange exchange = new BionetExchange();

        // Addresses
        address rA = address(router);
        address vA = address(voucher);
        address eA = address(exchange);

        router.initialize(eA);
        voucher.initialize(eA);
        exchange.initialize(rA, vA);

        vm.stopBroadcast();

        console.log("~~ deployed to local Anvil~~");
        console.log("router:   %s", rA);
        console.log("voucher:  %s", vA);
        console.log("exchange: %s", eA);
        */
    }
}
