// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {IpAsset} from "../mocks/IpAsset.sol";
import {BionetConfig} from "../../src/BionetConfig.sol";
import {BionetExchange} from "../../src/BionetExchange.sol";
import {BionetTreasury} from "../../src/BionetTreasury.sol";
import {BionetExchangeFactory} from "../../src/BionetExchangeFactory.sol";

import {Test} from "forge-std/Test.sol";

///
contract InvariantBase is Test {
    uint256 internal constant FUNDING = 1e36;
    uint256 internal constant ONE_WEEK = 7 days;
    uint256 internal constant FEE_BASIS_POINTS = 200;

    address internal governor;

    address internal config;
    address internal factory;
    address internal treasury;
    address internal template;

    function setUp() public virtual {
        _createAccounts();
        _createBaseContracts();
    }

    function _createAccounts() internal {
        governor = address(0x111);
        vm.deal(governor, FUNDING);
    }

    function _createBaseContracts() internal {
        // Create Config and treasury
        vm.startPrank(governor);
        config = address(new BionetConfig());
        treasury = address(new BionetTreasury());
        vm.stopPrank();

        // Create template
        template = address(new BionetExchange());

        // Create factory connected to config
        factory = address(new BionetExchangeFactory(config));

        vm.startPrank(governor);
        BionetConfig c = BionetConfig(config);
        c.setExchangeTemplate(template);
        c.setTreasury(treasury);
        c.setProtocolFee(FEE_BASIS_POINTS);
        vm.stopPrank();
    }

    /// *** Invariants Tests ***
    ///
    /// * Exchange
    ///   * A: ether balance >= escrow balance
    ///   * B: fundAvailable == finalizedDate > 0
    ///   * C: total escrow >= seller + buyer deposits
    ///   * D: total withdraw <= totalEscrow
    ///
    /// * Treasury
    ///   * A: always increases
    ///   * B: always >= sum of all escrow
}

// To create generic addresses for buyers & sellers
contract Address {

}
