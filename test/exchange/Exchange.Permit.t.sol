// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {BaseTest} from "../utils/BaseTest.sol";
import {SigUtils} from "../utils/SigUtils.sol";

import {
    Exchange, ExchangeArgs, ExchangePermitArgs
} from "../../src/BionetTypes.sol";
import {ExchangeFacet} from "../../src/facets/ExchangeFacet.sol";

import {IDiamondCut} from "diamond/interfaces/IDiamondCut.sol";

contract ExchangePermitTest is BaseTest {
    uint256 exchangeId;

    function setUp() public override {
        super.setUp();

        vm.startPrank(seller);
        ExchangeArgs memory args = defaultExchangeArgs();
        exchangeId = ExchangeFacet(diamondAddress).createOffer(args);
        vm.stopPrank();
    }

    function test_permit_bad_signature() public {
        SigUtils.Permit memory permit = makePermit(buyer, 0);

        // Wrong signer: buyer is the owner
        uint256 wrongSigner = 0xbadbad;
        bytes32 hashed = sigUtil.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongSigner, hashed);

        vm.startPrank(buyer);
        vm.expectRevert("INVALID_SIGNER");
        ExchangeFacet(diamondAddress).fundOffer(
            exchangeId,
            ExchangePermitArgs({v: v, r: r, s: s, validFor: defaultPermitExpiration})
        );
        vm.stopPrank();
    }

    function test_permit_valid() public {
        SigUtils.Permit memory permit = makePermit(buyer, 0);
        bytes32 hashed = sigUtil.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerSecretKey, hashed);

        vm.startPrank(buyer);
        ExchangeFacet(diamondAddress).fundOffer(
            exchangeId,
            ExchangePermitArgs({v: v, r: r, s: s, validFor: defaultPermitExpiration})
        );
        vm.stopPrank();

        assertEq(usdc.balanceOf(diamondAddress), defaultPrice);
        assertEq(usdc.balanceOf(buyer), BUYER_INITIAL_BALANCE - defaultPrice);
    }

    function test_permit_expires() public {
        uint256 expireIn = 1 days;

        SigUtils.Permit memory permit = makePermit(buyer, 0);
        permit.deadline = expireIn;

        bytes32 hashed = sigUtil.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerSecretKey, hashed);

        vm.warp(block.timestamp + 2 days);

        vm.startPrank(buyer);
        vm.expectRevert("PERMIT_DEADLINE_EXPIRED");
        ExchangeFacet(diamondAddress).fundOffer(
            exchangeId, ExchangePermitArgs({v: v, r: r, s: s, validFor: expireIn})
        );
        vm.stopPrank();
    }
}
