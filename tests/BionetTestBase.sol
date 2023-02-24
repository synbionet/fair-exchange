// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {IpAsset} from "./mocks/IpAsset.sol";
import {BionetConfig} from "../src/BionetConfig.sol";
import {BionetExchange} from "../src/BionetExchange.sol";
import {BionetTreasury} from "../src/BionetTreasury.sol";
import {BionetExchangeFactory} from "../src/BionetExchangeFactory.sol";

import "forge-std/Test.sol";

contract BionetTestBase is Test {
    address payable buyer;
    address payable seller;
    address payable treasurer;
    address governor;

    address asset;
    //address treasury;

    address config;
    address template;
    address factory;

    // Big funding to handle fuzzing
    uint256 public constant FUNDING = 1e36;

    function setUp() public virtual {
        _createAccounts();
        _createDepContract();
    }

    function _createAccounts() internal {
        buyer = payable(address(0x1111));
        seller = payable(address(0x2222));
        treasurer = payable(address(0x3333));

        vm.deal(buyer, FUNDING);
        vm.deal(seller, FUNDING);
        vm.deal(governor, FUNDING);
        vm.deal(treasurer, FUNDING);
    }

    function _createDepContract() internal {
        address treas;

        // Create config
        vm.startPrank(governor);
        config = address(new BionetConfig());
        vm.stopPrank();

        // Create treasury
        vm.startPrank(treasurer);
        treas = address(new BionetTreasury());
        vm.stopPrank();

        // Create template
        template = address(new BionetExchange());

        // Create factory connected to config
        factory = address(new BionetExchangeFactory(config));

        // Set values on config
        vm.startPrank(governor);
        BionetConfig c = BionetConfig(config);
        c.setExchangeTemplate(template);
        c.setTreasury(treas);
        c.setProtocolFee(200);
        vm.stopPrank();

        vm.startPrank(seller);
        IpAsset ia = new IpAsset();
        asset = address(ia);
        vm.stopPrank();
    }

    function createExchange(uint256[4] memory _terms)
        internal
        returns (address exchange)
    {
        uint256 dueFromSeller = _terms[2];

        vm.startPrank(seller);
        exchange = BionetExchangeFactory(factory).createExchange{
            value: dueFromSeller
        }(buyer, asset, _terms);
        vm.stopPrank();
    }

    function assertEscrowBalances(
        address exchange,
        uint256 bBal,
        uint256 sBal
    ) public {
        assertEq(
            BionetExchange(exchange).escrowBalance(buyer),
            bBal,
            "Buyers Balance"
        );
        assertEq(
            BionetExchange(exchange).escrowBalance(seller),
            sBal,
            "Seller's Balance"
        );
    }
}
