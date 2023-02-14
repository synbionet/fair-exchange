// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import "../src/libs/FundsLib.sol";
import "./helpers/BaseBionetTest.sol";

contract ExchangeTest is BaseBionetTest {
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
        assetToken = address(ipAsset);
    }

    function testCreateOffer() public {
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // check the offer is stored on exchange
        (, BionetTypes.Offer memory o) = exchange.getOffer(offerId);
        assertEq(offerId, o.id);
        assertEq(seller, o.seller);
        assertEq(price, o.price);
    }

    function testCommit() public {
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // Buyer has to commit with the price of the offer
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // Check:
        // Buyer should have 'price' escrowed
        // Seller 0
        uint256 buyerBalAfterCommit = funds.getEscrowBalance(buyer);
        assertEq(price, buyerBalAfterCommit);
        uint256 sellerBalAfterCommit = funds.getEscrowBalance(seller);
        assertEq(0, sellerBalAfterCommit);

        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertEq(1, exc.id);
        assertEq(buyer, exc.buyer);
        assertEq(exc.redeemBy, block.timestamp + WEEK);
        assertTrue(exc.state == BionetTypes.ExchangeState.Committed);

        // Buyer should have a voucher for the exchange id (tokenid)
        assertEq(buyer, voucher.ownerOf(exchangeId));
    }

    function testRevoke() public {
        // seller makes offer
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        assertEq(voucher.balanceOf(buyer), 1);
        uint256 buyerBeforeRevoke = funds.getEscrowBalance(buyer);
        assertEq(price, buyerBeforeRevoke);

        // seller revokes the deal. Calculate their cost to do so
        uint256 revokeCost = FundsLib.calculateCost(
            price,
            BionetTypes.ExchangeState.Revoked
        );

        vm.startPrank(seller);
        router.revoke{value: revokeCost}(exchangeId);
        vm.stopPrank();

        uint256 sellerBal = funds.getEscrowBalance(seller);
        assertEq(sellerBal, 0);

        uint256 buyerAfterRevoke = funds.getEscrowBalance(buyer);
        assertEq(buyerAfterRevoke, price + revokeCost);

        // Check state of exchange
        // revoked, finalized, voucher burnt...
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertTrue(exc.state == BionetTypes.ExchangeState.Revoked);
        assertTrue(exc.finalizedDate == block.timestamp);
        assertEq(voucher.balanceOf(exc.buyer), 0);
    }

    function testRevokeWithExpired() public {
        // seller makes offer
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // Fastforward...
        vm.warp(block.timestamp + WEEK + 1 days);

        uint256 sellerBeforeBal = seller.balance;

        // seller revokes the deal. BUT, the redeem period has expired
        uint256 revokeCost = FundsLib.calculateCost(
            price,
            BionetTypes.ExchangeState.Revoked
        );

        vm.startPrank(seller);
        router.revoke{value: revokeCost}(exchangeId);
        vm.stopPrank();

        // reimbursed cost of transaction
        assertEq(seller.balance, sellerBeforeBal);

        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertTrue(exc.state == BionetTypes.ExchangeState.Canceled);
        assertTrue(exc.finalizedDate == block.timestamp);
        assertEq(voucher.balanceOf(exc.buyer), 0);
    }

    function testCancel() public {
        // seller makes offer
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        vm.startPrank(buyer);
        router.cancel(exchangeId);
        vm.stopPrank();

        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertTrue(exc.state == BionetTypes.ExchangeState.Canceled);
        assertTrue(exc.finalizedDate == block.timestamp);
        assertEq(voucher.balanceOf(exc.buyer), 0);
    }

    function testCancelWithExpire() public {
        // works the same as cancel

        // seller makes offer
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // Fastforward...
        vm.warp(block.timestamp + WEEK + 1 days);

        vm.startPrank(buyer);
        router.cancel(exchangeId);
        vm.stopPrank();

        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertTrue(exc.state == BionetTypes.ExchangeState.Canceled);
        assertTrue(exc.finalizedDate == block.timestamp);
        assertEq(voucher.balanceOf(exc.buyer), 0);
    }

    function testRedeem() public {
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertEq(voucher.balanceOf(exc.buyer), 1);

        // time travel a few days.  Still below voucher expiration
        vm.warp(block.timestamp + 3 days);

        vm.startPrank(buyer);
        router.redeem(exchangeId);
        vm.stopPrank();

        (, BionetTypes.Exchange memory exc1) = exchange.getExchange(exchangeId);
        assertTrue(exc1.state == BionetTypes.ExchangeState.Redeemed);
        assertTrue(exc1.finalizedDate == 0);
        assertEq(voucher.balanceOf(exc1.buyer), 0);
    }
}
