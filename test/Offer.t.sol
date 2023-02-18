// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import {BionetTestBase} from "./BionetTestBase.sol";

import {MockAsset} from "./mocks/MockAsset.sol";

/**
 */
contract OfferTest is BionetTestBase {
    uint256 constant price = 3.2 ether;
    uint256 requiredDeposit;

    function setUp() public virtual override {
        super.setUp();
        requiredDeposit = router.getSellerDeposit(price);
    }

    function test_deposit_createOffer() public {
        BionetTypes.Offer memory offer = mockOffer(
            seller,
            price,
            address(ipAsset),
            1
        );

        // Incorrect deposit
        vm.startPrank(seller);
        vm.expectRevert("Insufficient deposit");
        router.createOffer{value: requiredDeposit - 0.01 ether}(offer);
        vm.stopPrank();

        // No deposit
        vm.startPrank(seller);
        vm.expectRevert("Insufficient deposit");
        router.createOffer(offer);
        vm.stopPrank();

        // Valid deposit
        vm.startPrank(seller);
        router.createOffer{value: requiredDeposit}(offer);
        vm.stopPrank();

        // Correct escrow
        uint256 bal = router.getEscrowBalance(seller);
        assertEq(bal, requiredDeposit);
    }

    function test_only_router_createOffer() public {
        BionetTypes.Offer memory offer = mockOffer(
            seller,
            price,
            address(ipAsset),
            1
        );

        // Only the router can call exchange
        vm.startPrank(seller);
        vm.expectRevert("Unauthorized call");
        exchange.createOffer{value: requiredDeposit}(offer);
        vm.stopPrank();
    }

    function test_proper_ipAsset_createOffer() public {
        vm.startPrank(buyer);
        MockAsset wrongAsset = new MockAsset();
        vm.stopPrank();

        BionetTypes.Offer memory offer = mockOffer(
            seller,
            price,
            address(wrongAsset),
            1
        );

        // Fails: buyer owns the asset - not the seller
        vm.startPrank(seller);
        vm.expectRevert("Don't own enough IP tokens to offer");
        router.createOffer{value: requiredDeposit}(offer);
        vm.stopPrank();
    }

    function test_ipAsset_exchange_approval_createOffer() public {
        // create asset minting 1 to the seller
        vm.startPrank(seller);
        MockAsset asset = new MockAsset();
        vm.stopPrank();

        BionetTypes.Offer memory offer = mockOffer(
            seller,
            price,
            address(asset),
            1
        );

        // Seller didn't approve the exchange to transfer asset
        vm.startPrank(seller);
        vm.expectRevert(
            "Exchange must be approved to transfer your IP NFT tokens"
        );
        router.createOffer{value: requiredDeposit}(offer);
        vm.stopPrank();

        // Seller didn't approve the right (exchange) address to transfer asset
        vm.startPrank(seller);
        asset.setApprovalForAll(address(0x777), true);
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert(
            "Exchange must be approved to transfer your IP NFT tokens"
        );
        router.createOffer{value: requiredDeposit}(offer);
        vm.stopPrank();

        // Now approves correctly
        vm.startPrank(seller);
        asset.setApprovalForAll(address(exchange), true);
        vm.stopPrank();

        vm.startPrank(seller);
        router.createOffer{value: requiredDeposit}(offer);
        vm.stopPrank();
    }

    function test_nozero_address_createOffer() public {
        BionetTypes.Offer memory offer = mockOffer(
            seller,
            price,
            address(ipAsset),
            1
        );

        address zero = address(0x0);
        vm.deal(zero, 5 ether);

        vm.startPrank(zero);
        vm.expectRevert("Bad Address");
        router.createOffer{value: requiredDeposit}(offer);
        vm.stopPrank();
    }
}
