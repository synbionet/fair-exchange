// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import {FundsLib} from "../src/libs/FundsLib.sol";
import {BionetTestBase} from "./BionetTestBase.sol";
import {CANCEL_REVOKE_FEE, WEEK} from "../src/BionetConstants.sol";

import {MockAsset} from "./mocks/MockAsset.sol";

/**
 */
contract CancelTest is BionetTestBase {
    uint256 constant offerPrice = 3 ether;
    uint256 cancelFee;

    function setUp() public virtual override {
        super.setUp();
        cancelFee = FundsLib.calculateFee(offerPrice, CANCEL_REVOKE_FEE);
    }

    // Buyer gets the correct refund
    function test_withdraw_cancel() public {
        uint256 offerId;
        uint256 exchangeId;
        (offerId, exchangeId) = _createOfferAndCommit(offerPrice);

        uint256 expectedRefund = offerPrice - cancelFee;

        // Cancel
        vm.startPrank(buyer);
        assertEq(voucher.balanceOf(buyer), 1);
        router.cancel(exchangeId);
        vm.stopPrank();

        // Check escrow
        uint256 bal = router.getEscrowBalance(buyer);
        assertEq(bal, expectedRefund);

        // Withdraw money
        // eth balance > than before
        // escrow balance == 0 (in this case)
        uint256 ebb = buyer.balance;

        vm.startPrank(buyer);
        router.withdraw();
        vm.stopPrank();

        uint256 eba = buyer.balance;

        assertGt(eba, ebb);
        uint256 bala = router.getEscrowBalance(buyer);
        assertEq(bala, 0);

        // Check the voucher is gone
        assertEq(voucher.balanceOf(buyer), 0);
    }

    function test_expire_cancel() public {
        // Expire works the same as cancel
        uint256 offerId;
        uint256 exchangeId;
        (offerId, exchangeId) = _createOfferAndCommit(offerPrice);
        uint256 expectedRefund = offerPrice - cancelFee;

        assertEq(voucher.balanceOf(buyer), 1);

        // expire the exchange
        vm.warp(block.timestamp + WEEK + 1 days);

        // Note: We need to trigger the timer.
        // We'll do that by trying to redeem it.
        vm.startPrank(buyer);
        router.redeem(exchangeId);
        vm.stopPrank();

        // Check escrow
        uint256 bal = router.getEscrowBalance(buyer);
        assertEq(bal, expectedRefund);

        // Withdraw money
        // eth balance > than before
        // escrow balance == 0 (in this case)
        uint256 ebb = buyer.balance;

        vm.startPrank(buyer);
        router.withdraw();
        vm.stopPrank();

        uint256 eba = buyer.balance;

        assertGt(eba, ebb);
        uint256 bala = router.getEscrowBalance(buyer);
        assertEq(bala, 0);

        // Check the state of the exchange
        (, BionetTypes.Exchange memory exchange) = exchange.getExchange(
            exchangeId
        );
        assertTrue(exchange.state == BionetTypes.ExchangeState.Canceled);
        assertEq(exchange.finalizedDate, block.timestamp);

        // Check the voucher is gone
        assertEq(voucher.balanceOf(buyer), 0);
    }
}
