// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {BaseTest} from "../utils/BaseTest.sol";
import {SigUtils} from "../utils/SigUtils.sol";

import {
    Exchange, ExchangeArgs, ExchangePermitArgs
} from "../../src/BionetTypes.sol";

import {UnAuthorizedCaller, InsufficientFunds} from "../../src/Errors.sol";
import {ExchangeFacet} from "../../src/facets/ExchangeFacet.sol";

import {IDiamondCut} from "diamond/interfaces/IDiamondCut.sol";

contract ExchangeFundTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_create_exchange() public {
        ExchangeArgs memory args = defaultExchangeArgs();
        vm.startPrank(seller);
        uint256 id = ExchangeFacet(diamondAddress).createOffer(args);
        vm.stopPrank();

        (, Exchange memory back) = ExchangeFacet(diamondAddress).getExchange(id);
        assertEq(back.seller, seller);
        assertEq(back.buyer, buyer);
        assertEq(back.price, defaultPrice);
    }

    function test_fund_offer_expires() public {
        ExchangeArgs memory args = defaultExchangeArgs();
        vm.startPrank(seller);
        uint256 id = ExchangeFacet(diamondAddress).createOffer(args);
        vm.stopPrank();

        SigUtils.Permit memory permit = makePermit(buyer, 0);
        bytes32 hashed = sigUtil.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerSecretKey, hashed);

        vm.warp(block.timestamp + 20 days);

        assertFalse(ExchangeFacet(diamondAddress).isClosed(id));

        vm.startPrank(buyer);
        ExchangeFacet(diamondAddress).fundOffer(
            id,
            ExchangePermitArgs({v: v, r: r, s: s, validFor: defaultPermitExpiration})
        );
        vm.stopPrank();

        assertTrue(ExchangeFacet(diamondAddress).isClosed(id));
    }

    function test_can_trigger_offer_expire() public {
        ExchangeArgs memory args = defaultExchangeArgs();
        vm.startPrank(seller);
        uint256 id = ExchangeFacet(diamondAddress).createOffer(args);
        vm.stopPrank();

        vm.warp(block.timestamp + 20 days);

        assertFalse(ExchangeFacet(diamondAddress).isClosed(id));

        vm.startPrank(seller);
        bool r = ExchangeFacet(diamondAddress).triggerTimer(id);
        vm.stopPrank();
        assertTrue(r);

        assertTrue(ExchangeFacet(diamondAddress).isClosed(id));
    }

    function test_fund_unauthorized_caller() public {
        ExchangeArgs memory args = defaultExchangeArgs();
        vm.startPrank(seller);
        uint256 id = ExchangeFacet(diamondAddress).createOffer(args);
        vm.stopPrank();

        SigUtils.Permit memory permit = makePermit(buyer, 0);
        bytes32 hashed = sigUtil.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerSecretKey, hashed);

        // Will fail as we're not pranking the buyer in the call below
        vm.expectRevert(UnAuthorizedCaller.selector);
        ExchangeFacet(diamondAddress).fundOffer(
            id,
            ExchangePermitArgs({v: v, r: r, s: s, validFor: defaultPermitExpiration})
        );
    }

    function test_fund_insufficient_usd_funds() public {
        address brokeBuyer = vm.addr(0x11);
        vm.deal(brokeBuyer, 1 ether);

        ExchangeArgs memory args = defaultExchangeArgs();
        args.buyer = brokeBuyer;

        vm.startPrank(seller);
        uint256 id = ExchangeFacet(diamondAddress).createOffer(args);
        vm.stopPrank();

        SigUtils.Permit memory permit = makePermit(brokeBuyer, 0);
        bytes32 hashed = sigUtil.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x11, hashed);

        vm.startPrank(brokeBuyer);
        vm.expectRevert(InsufficientFunds.selector);
        ExchangeFacet(diamondAddress).fundOffer(
            id,
            ExchangePermitArgs({v: v, r: r, s: s, validFor: defaultPermitExpiration})
        );
        vm.stopPrank();
    }

    function test_fund_transfers_to_escrow() public {
        ExchangeArgs memory args = defaultExchangeArgs();
        vm.startPrank(seller);
        uint256 id = ExchangeFacet(diamondAddress).createOffer(args);
        vm.stopPrank();

        SigUtils.Permit memory permit = makePermit(buyer, 0);
        bytes32 hashed = sigUtil.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerSecretKey, hashed);

        vm.startPrank(buyer);
        ExchangeFacet(diamondAddress).fundOffer(
            id,
            ExchangePermitArgs({v: v, r: r, s: s, validFor: defaultPermitExpiration})
        );
        vm.stopPrank();

        assertEq(usdc.balanceOf(diamondAddress), defaultPrice);
        assertEq(usdc.balanceOf(buyer), BUYER_INITIAL_BALANCE - defaultPrice);
    }
}
