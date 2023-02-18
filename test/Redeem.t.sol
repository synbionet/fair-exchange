// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import {WEEK} from "../src/BionetConstants.sol";
import {BionetTestBase} from "./BionetTestBase.sol";

/**
 */
contract RedeemTest is BionetTestBase {
    uint256 constant offerPrice = 3 ether;

    function test_good_redeem() public {
        uint256 offerId;
        uint256 exchangeId;
        (offerId, exchangeId) = _createOfferAndCommit(offerPrice);

        // Buyer has a voucher
        assertEq(voucher.balanceOf(buyer), 1);

        vm.startPrank(buyer);
        router.redeem(exchangeId);
        vm.stopPrank();

        // Buyer burned voucher
        assertEq(voucher.balanceOf(buyer), 0);

        // Money still escrowed
        uint256 bal = router.escrowBalance(buyer);
        assertEq(bal, offerPrice);

        // Check the state of the exchange = CANCELED
        BionetTypes.Exchange memory exchange = exchange.getExchange(exchangeId);
        assertTrue(exchange.state == BionetTypes.ExchangeState.Redeemed);
        assertEq(exchange.disputeBy, block.timestamp + WEEK);
    }

    function test_buyer_cant_withdraw_in_redeem() public {
        uint256 offerId;
        uint256 exchangeId;
        (offerId, exchangeId) = _createOfferAndCommit(offerPrice);

        uint256 eb = router.escrowBalance(buyer);
        assertEq(eb, offerPrice);

        vm.startPrank(buyer);
        router.redeem(exchangeId);
        vm.stopPrank();

        uint256 ea = router.escrowBalance(buyer);
        assertEq(ea, offerPrice);

        vm.startPrank(buyer);
        router.withdraw();
        vm.stopPrank();

        uint256 ea1 = router.escrowBalance(buyer);
        assertEq(ea1, offerPrice);
    }
}
