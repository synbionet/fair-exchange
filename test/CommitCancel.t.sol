// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import "../src/libs/FundsLib.sol";
import "./helpers/BaseBionetTest.sol";

contract CommitCancelTest is BaseBionetTest {
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

    function testGoodCancel() public {
        // seller makes offer
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        uint256 cancelCost = FundsLib.calculateCost(
            price,
            BionetTypes.ExchangeState.Canceled
        );

        uint256 escrowBeforeCancel = funds.getEscrowBalance(buyer);
        assertEq(escrowBeforeCancel, price);

        vm.startPrank(buyer);
        router.cancel(exchangeId);
        vm.stopPrank();

        // Buyer's escrow is not less the cost of canceling
        uint256 escrowAfterCancel = funds.getEscrowBalance(buyer);
        assertEq(escrowAfterCancel, price - cancelCost);

        // correct state, voucher burned, etc...
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertTrue(exc.state == BionetTypes.ExchangeState.Canceled);
        assertTrue(exc.finalizedDate == block.timestamp);
        assertEq(voucher.balanceOf(exc.buyer), 0);
    }

    function testCancelSameAsExpired() public {
        // seller makes offer
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        uint256 cancelCost = FundsLib.calculateCost(
            price,
            BionetTypes.ExchangeState.Canceled
        );

        uint256 escrowBeforeCancel = funds.getEscrowBalance(buyer);
        assertEq(escrowBeforeCancel, price);

        // Fast forward time to make the commit expired
        vm.warp(block.timestamp + WEEK + 1 days);

        vm.startPrank(buyer);
        router.cancel(exchangeId);
        vm.stopPrank();

        // Buyer's escrow is not less the cost of canceling
        uint256 escrowAfterCancel = funds.getEscrowBalance(buyer);
        assertEq(escrowAfterCancel, price - cancelCost);

        // correct state, voucher burned, etc...
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertTrue(exc.state == BionetTypes.ExchangeState.Canceled);
        assertTrue(exc.finalizedDate == block.timestamp);
        assertEq(voucher.balanceOf(exc.buyer), 0);
    }
}
