// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import "../src/libs/FundsLib.sol";
import "./helpers/BaseBionetTest.sol";

contract CommitRedeemTest is BaseBionetTest {
    // NOTE: seller is from Base
    address buyer = address(this);

    // common params used in tests
    uint256 price;
    uint256 assetTokenId;
    address assetToken;

    function setUp() public virtual override {
        super.setUp();
        vm.deal(buyer, 10 ether);

        price = 2.7 ether;
        assetTokenId = 1;
        // ipAsset comes from base
        assetToken = address(ipAsset);
    }

    function testGoodRedeem() public {
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // Buyer has a voucher before redeem
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertEq(voucher.balanceOf(exc.buyer), 1);

        // time travel a few days.  Still below voucher expiration
        vm.warp(block.timestamp + 3 days);

        vm.startPrank(buyer);
        router.redeem(exchangeId);
        vm.stopPrank();

        // Funds are still escrowed
        uint256 escrowBal = funds.getEscrowBalance(buyer);
        assertEq(escrowBal, price);

        // state changed, voucher burned, not finalized
        (, BionetTypes.Exchange memory exc1) = exchange.getExchange(exchangeId);
        assertTrue(exc1.state == BionetTypes.ExchangeState.Redeemed);
        assertTrue(exc1.finalizedDate == 0);
        // new timer started
        assertTrue(exc1.disputeBy == block.timestamp + WEEK);
        assertEq(voucher.balanceOf(exc1.buyer), 0);
    }

    function testCantRedeemOnTimerExpire() public {
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // Buyer has a voucher before redeem
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertEq(voucher.balanceOf(exc.buyer), 1);

        uint256 bbb = funds.getEscrowBalance(buyer);
        uint256 sbb = funds.getEscrowBalance(seller);

        // time travel to expire redeem period
        vm.warp(block.timestamp + WEEK + 1 days);

        uint256 expireCost = FundsLib.calculateCost(
            price,
            BionetTypes.ExchangeState.Canceled
        );

        vm.startPrank(buyer);
        router.redeem(exchangeId);
        vm.stopPrank();

        // Exchange is canceled by the protocol!
        (, BionetTypes.Exchange memory exc1) = exchange.getExchange(exchangeId);
        assertTrue(exc1.state == BionetTypes.ExchangeState.Canceled);
        assertTrue(exc1.finalizedDate == block.timestamp);
        assertEq(voucher.balanceOf(exc1.buyer), 0);

        uint256 bba = funds.getEscrowBalance(buyer);
        uint256 sba = funds.getEscrowBalance(seller);

        assertTrue(bba == bbb - expireCost);
        assertTrue(sba == sbb + expireCost);
    }
}
