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
import {FromStorage} from "../../src/facets/FromStorage.sol";
import {ExchangeFacet} from "../../src/facets/ExchangeFacet.sol";

import {IDiamondCut} from "diamond/interfaces/IDiamondCut.sol";

contract ExchangeRefundTest is BaseTest {
    uint128 price = 10e6;
    uint256 expectedModeratorPayout = 200000; // 10e6 * 2%

    function setUp() public override {
        super.setUp();
    }

    function deployAndResolve(RefundType _rt) internal returns (uint256 eid) {
        // Create the offer

        ExchangeArgs memory args = defaultExchangeArgs();
        args.price = price;

        vm.startPrank(seller);
        eid = ExchangeFacet(diamondAddress).createOffer(args);
        vm.stopPrank();

        // buyer funds it and then disputes it
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: buyer,
            spender: diamondAddress,
            value: price,
            nonce: 0,
            deadline: defaultPermitExpiration
        });
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

        // Moderator call resolve
        vm.startPrank(moderator);
        ExchangeFacet(diamondAddress).resolve(eid, _rt);
        vm.stopPrank();
    }

    function test_refund_full() public {
        uint256 eid = deployAndResolve(RefundType.Full);

        assertEq(usdc.balanceOf(buyer), BUYER_INITIAL_BALANCE - price);

        vm.startPrank(buyer);
        ExchangeFacet(diamondAddress).agreeToRefund(eid);
        vm.stopPrank();

        address treasury = FromStorage(diamondAddress).treasury();

        assertEq(usdc.balanceOf(seller), 0);
        assertEq(usdc.balanceOf(treasury), 0);
        assertEq(usdc.balanceOf(diamondAddress), 0);
        assertEq(
            usdc.balanceOf(buyer), BUYER_INITIAL_BALANCE - expectedModeratorPayout
        );
        assertEq(usdc.balanceOf(moderator), expectedModeratorPayout);
    }

    function test_refund_partial() public {
        uint256 eid = deployAndResolve(RefundType.Partial);

        assertEq(usdc.balanceOf(buyer), BUYER_INITIAL_BALANCE - price);

        address treasury = FromStorage(diamondAddress).treasury();

        vm.startPrank(buyer);
        ExchangeFacet(diamondAddress).agreeToRefund(eid);
        vm.stopPrank();

        assertEq(usdc.balanceOf(seller), 4900000);
        assertEq(usdc.balanceOf(treasury), 0);
        assertEq(usdc.balanceOf(diamondAddress), 0);
        assertEq(usdc.balanceOf(buyer), BUYER_INITIAL_BALANCE - price + 4900000);
        assertEq(usdc.balanceOf(moderator), expectedModeratorPayout);
    }

    function test_refund_none() public {
        // Seller gets paid less moderator fee: 9800000
        uint256 eid = deployAndResolve(RefundType.None);

        assertEq(usdc.balanceOf(buyer), BUYER_INITIAL_BALANCE - price);

        address treasury = FromStorage(diamondAddress).treasury();

        vm.startPrank(seller);
        ExchangeFacet(diamondAddress).agreeToRefund(eid);
        vm.stopPrank();

        assertEq(usdc.balanceOf(seller), 9800000);
        assertEq(usdc.balanceOf(treasury), 0);
        assertEq(usdc.balanceOf(diamondAddress), 0);
        assertEq(usdc.balanceOf(buyer), BUYER_INITIAL_BALANCE - price);
        assertEq(usdc.balanceOf(moderator), expectedModeratorPayout);
    }

    function test_cant_refund_timer_expired() public {
        uint256 eid = deployAndResolve(RefundType.None);

        vm.warp(block.timestamp + 32 days);

        vm.startPrank(seller);
        vm.expectRevert(ExchangeFacet.TimerExpired.selector);
        ExchangeFacet(diamondAddress).agreeToRefund(eid);
        vm.stopPrank();
    }

    function test_refund_trigger_timer_expired() public {
        uint256 eid = deployAndResolve(RefundType.None);
        vm.warp(block.timestamp + 32 days);

        vm.startPrank(seller);
        bool result = ExchangeFacet(diamondAddress).triggerTimer(eid);
        assertTrue(result);
        vm.stopPrank();

        address treasury = FromStorage(diamondAddress).treasury();
        assertEq(usdc.balanceOf(seller), 9800000);
        assertEq(usdc.balanceOf(treasury), 200000);
        assertEq(usdc.balanceOf(diamondAddress), 0);
        assertEq(usdc.balanceOf(buyer), BUYER_INITIAL_BALANCE - price);
        assertEq(usdc.balanceOf(moderator), 0);
    }
}
