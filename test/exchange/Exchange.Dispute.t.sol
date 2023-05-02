// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {BaseTest} from "../utils/BaseTest.sol";
import {SigUtils} from "../utils/SigUtils.sol";

import {
    Exchange, ExchangeArgs, ExchangePermitArgs
} from "../../src/BionetTypes.sol";
import {FromStorage} from "../../src/facets/FromStorage.sol";
import {ExchangeFacet} from "../../src/facets/ExchangeFacet.sol";

import {IDiamondCut} from "diamond/interfaces/IDiamondCut.sol";

contract ExchangeDisputeTest is BaseTest {
    uint256 expectedProtocolPayout = 400000; // defaultPrice * 2%

    function setUp() public override {
        super.setUp();
    }

    function deployAndFund(ExchangeArgs memory _args)
        internal
        returns (uint256 eid)
    {
        // Create the offer
        vm.startPrank(seller);
        eid = ExchangeFacet(diamondAddress).createOffer(_args);
        vm.stopPrank();

        // buyer funds it
        SigUtils.Permit memory permit = makePermit(buyer, 0);
        bytes32 hashed = sigUtil.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerSecretKey, hashed);

        vm.startPrank(buyer);
        ExchangeFacet(diamondAddress).fundOffer(
            eid,
            ExchangePermitArgs({v: v, r: r, s: s, validFor: defaultPermitExpiration})
        );
        vm.stopPrank();
    }

    function test_cant_dispute_free_stuff() public {
        ExchangeArgs memory args = defaultExchangeArgs();
        args.price = 0;

        uint256 eid = deployAndFund(args);

        vm.startPrank(buyer);
        vm.expectRevert(ExchangeFacet.CantDisputeFreeStuff.selector);
        ExchangeFacet(diamondAddress).dispute(eid);
        vm.stopPrank();
    }

    function test_dispute_expired_timer() public {
        ExchangeArgs memory args = defaultExchangeArgs();
        uint256 eid = deployAndFund(args);

        vm.warp(block.timestamp + defaultDisputeTime + 1 days);

        vm.startPrank(buyer);
        vm.expectRevert(ExchangeFacet.TimerExpired.selector);
        ExchangeFacet(diamondAddress).dispute(eid);
        vm.stopPrank();
    }

    function test_dispute_cant_trigger_if_timer_not_expired() public {
        ExchangeArgs memory args = defaultExchangeArgs();
        uint256 eid = deployAndFund(args);

        vm.startPrank(seller);
        bool result = ExchangeFacet(diamondAddress).triggerTimer(eid);
        assertFalse(result);
        vm.stopPrank();
    }

    function test_dispute_release_funds_on_expired() public {
        ExchangeArgs memory args = defaultExchangeArgs();
        uint256 eid = deployAndFund(args);

        vm.warp(block.timestamp + defaultDisputeTime + 1 days);

        vm.startPrank(seller);
        bool result = ExchangeFacet(diamondAddress).triggerTimer(eid);
        assertTrue(result);
        vm.stopPrank();

        address treasury = FromStorage(diamondAddress).treasury();

        assertEq(usdc.balanceOf(diamondAddress), 0);
        assertEq(usdc.balanceOf(seller), (defaultPrice - expectedProtocolPayout));
        assertEq(usdc.balanceOf(treasury), expectedProtocolPayout);
    }
}
