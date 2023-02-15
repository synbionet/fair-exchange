// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import "../src/BionetConstants.sol";
import "../src/libs/FundsLib.sol";
import "./helpers/BaseBionetTest.sol";

contract RedeemCompleteTest is BaseBionetTest {
    // NOTE: seller is from Base
    address payable buyer = payable(address(0x555));

    // common params used in tests
    uint256 price;
    uint256 assetTokenId;
    address assetToken;

    function setUp() public virtual override {
        super.setUp();
        vm.deal(buyer, 10 ether);

        price = 4.7 ether;
        assetTokenId = 1;
        assetToken = address(ipAsset);
    }

    function testGoodFinalize() public {
        // start redeem setup
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // Buyer has a voucher before redeem
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertEq(voucher.balanceOf(exc.buyer), 1);

        vm.startPrank(buyer);
        router.redeem(exchangeId);
        vm.stopPrank();
        // end redeem setup

        uint256 CF = FundsLib.calculateFee(price, PROTOCOL_FEE);

        // call finalize
        vm.startPrank(buyer);
        router.finalize(exchangeId);
        vm.stopPrank();

        // check exchange state
        (, BionetTypes.Exchange memory exc1) = exchange.getExchange(exchangeId);
        assertTrue(exc1.state == BionetTypes.ExchangeState.Completed);
        assertTrue(exc1.finalizedDate == block.timestamp);

        (, BionetTypes.Offer memory o) = exchange.getOffer(offerId);

        // Check asset is transfered
        uint256 ab = ipAsset.balanceOf(exc1.buyer, o.assetTokenId);
        assertTrue(ab == o.quantityAvailable);

        // check balances
        uint256 bba = funds.getEscrowBalance(buyer);
        uint256 sba = funds.getEscrowBalance(seller);
        uint256 pba = funds.getProtocolBalance();

        // Buyers escrow is 0
        assertTrue(bba == 0);
        // Seller escrow is price - CF
        assertTrue(sba == (price - CF));
        // Protocol bal == CF
        assertTrue(pba == CF);
    }

    function testAnyoneCanFinalizeIfExpired() public {
        // start redeem setup
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // Buyer has a voucher before redeem
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertEq(voucher.balanceOf(exc.buyer), 1);

        vm.startPrank(buyer);
        router.redeem(exchangeId);
        vm.stopPrank();
        // end redeem setup

        // Fast forward time to make the disputeBy expired
        vm.warp(block.timestamp + WEEK + 1 days);

        uint256 CF = FundsLib.calculateFee(price, PROTOCOL_FEE);

        // NOTE SELLER finalizes!
        vm.startPrank(seller);
        router.finalize(exchangeId);
        vm.stopPrank();

        // check exchange state
        (, BionetTypes.Exchange memory exc1) = exchange.getExchange(exchangeId);
        assertTrue(exc1.state == BionetTypes.ExchangeState.Completed);
        assertTrue(exc1.finalizedDate == block.timestamp);

        // check balances
        uint256 bba = funds.getEscrowBalance(buyer);
        uint256 sba = funds.getEscrowBalance(seller);
        uint256 pba = funds.getProtocolBalance();

        // Buyers escrow is 0
        assertTrue(bba == 0);
        // Seller escrow is price - CF
        assertTrue(sba == (price - CF));
        // Protocol bal == CF
        assertTrue(pba == CF);
    }

    function testMustBeBuyerOrExpired() public {
        // start redeem setup
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // Buyer has a voucher before redeem
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertEq(voucher.balanceOf(exc.buyer), 1);

        vm.startPrank(buyer);
        router.redeem(exchangeId);
        vm.stopPrank();
        // end redeem setup

        vm.startPrank(seller);
        vm.expectRevert("Not authorized to finalize the exchange");
        router.finalize(exchangeId);
        vm.stopPrank();
    }
}
