// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {BaseTest} from "../utils/BaseTest.sol";
import {SigUtils} from "../utils/SigUtils.sol";

import {
    Exchange,
    ExchangeArgs,
    ExchangePermitArgs,
    RefundType,
    RESOLVE_EXPIRES
} from "../../src/BionetTypes.sol";
import {UnAuthorizedCaller} from "../../src/Errors.sol";
import {FromStorage} from "../../src/facets/FromStorage.sol";
import {ExchangeFacet} from "../../src/facets/ExchangeFacet.sol";

import {IDiamondCut} from "diamond/interfaces/IDiamondCut.sol";

contract ExchangeResolveTest is BaseTest {
    uint256 expectedProtocolPayout = 400000; // defaultPrice * 2%

    function setUp() public override {
        super.setUp();
    }

    function deployAndFundAndDispute() internal returns (uint256 eid) {
        // Create the offer
        vm.startPrank(seller);
        ExchangeArgs memory args = defaultExchangeArgs();
        eid = ExchangeFacet(diamondAddress).createOffer(args);
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

        vm.warp(block.timestamp + 1 weeks);

        ExchangeFacet(diamondAddress).dispute(eid);
        vm.stopPrank();
    }

    function test_resolve_unauthorized() public {
        uint256 eid = deployAndFundAndDispute();

        // using a bad moderator
        address wrong_caller = address(0xbad);
        vm.startPrank(wrong_caller);
        vm.expectRevert(UnAuthorizedCaller.selector);
        ExchangeFacet(diamondAddress).resolve(eid, RefundType.Full);
        vm.stopPrank();
    }

    function test_resolve_timer_expired() public {
        uint256 eid = deployAndFundAndDispute();

        vm.warp(block.timestamp + RESOLVE_EXPIRES + 1 days);

        vm.startPrank(moderator);
        vm.expectRevert(ExchangeFacet.TimerExpired.selector);
        ExchangeFacet(diamondAddress).resolve(eid, RefundType.Full);
        vm.stopPrank();
    }

    function test_resolve_seller_can_trigger() public {
        uint256 eid = deployAndFundAndDispute();

        vm.warp(block.timestamp + RESOLVE_EXPIRES + 1 days);

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
