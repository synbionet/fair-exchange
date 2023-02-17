// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import {FundsLib} from "../src/libs/FundsLib.sol";
import {BionetTestBase} from "./BionetTestBase.sol";
import {CANCEL_REVOKE_FEE, WEEK} from "../src/BionetConstants.sol";

import {MockAsset} from "./mocks/MockAsset.sol";

/**
 */
contract RevokeTest is BionetTestBase {
    uint256 constant offerPrice = 3 ether;
    uint256 revokeFee;

    function setUp() public virtual override {
        super.setUp();
        revokeFee = FundsLib.calculateFee(offerPrice, CANCEL_REVOKE_FEE);
    }

    function test_withdraw_revoke() public {
        uint256 offerId;
        uint256 exchangeId;
        (offerId, exchangeId) = _createOfferAndCommit(offerPrice);

        // to buyer
        uint256 expectedRefund = offerPrice + revokeFee;

        // escrow
        uint256 beb = router.escrowBalance(buyer);
        uint256 seb = router.escrowBalance(seller);

        // Seller should have the revoke fee in escrow
        assertEq(seb, revokeFee, "seller");
        // Buyer should have 'price' in escrow
        assertEq(beb, offerPrice);

        // Buyer has a voucher
        assertEq(voucher.balanceOf(buyer), 1);

        // Seller revokes
        vm.startPrank(seller);
        router.revoke(exchangeId);
        vm.stopPrank();

        // Check post revoke escrow
        uint256 bea = router.escrowBalance(buyer);
        uint256 sea = router.escrowBalance(seller);
        assertEq(bea, expectedRefund);
        assertEq(sea, 0);

        // Now buyer withdraws
        uint256 ebb = buyer.balance;
        uint256 esb = seller.balance;

        // Buyer with draws
        vm.startPrank(buyer);
        router.withdraw();
        vm.stopPrank();

        // buyer loses voucher
        assertEq(voucher.balanceOf(buyer), 0);

        uint256 eba = buyer.balance;
        uint256 esa = seller.balance;

        // Buyer eth bal increases
        assertGt(eba, ebb);
        // No change to seller eth bal
        assertEq(esb, esa);
    }

    // Cancels instead of revoke
    function test_expire_revoke() public {
        uint256 offerId;
        uint256 exchangeId;
        (offerId, exchangeId) = _createOfferAndCommit(offerPrice);

        assertEq(voucher.balanceOf(buyer), 1);

        // expire the exchange
        vm.warp(block.timestamp + WEEK + 1 days);

        // Seller revokes
        vm.startPrank(seller);
        router.revoke(exchangeId);
        vm.stopPrank();

        // Check the state of the exchange = CANCELED
        BionetTypes.Exchange memory exchange = exchange.getExchange(exchangeId);
        assertTrue(exchange.state == BionetTypes.ExchangeState.Canceled);
        assertEq(exchange.finalizedDate, block.timestamp);

        // Check the voucher is gone
        assertEq(voucher.balanceOf(buyer), 0);
    }
}
