// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import "../src/libs/FundsLib.sol";
import "./helpers/BaseBionetTest.sol";

contract OfferCommitTest is BaseBionetTest {
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

    function testCreate() public {
        // Fail
        vm.expectRevert("Seller must be the caller");
        createOffer(seller, price, assetToken, assetTokenId);

        // Fail: Try to use an asset I don't own
        // ... assetToken is owned by seller NOT 'this'
        vm.expectRevert("Cannot sell more than you own");
        createOffer(address(this), price, assetToken, assetTokenId);

        // Fail: use a tokenId I don't own
        vm.startPrank(seller);
        vm.expectRevert("Cannot sell more than you own");
        createOffer(seller, price, assetToken, 100);
        vm.stopPrank();

        // Ok...
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // check the offer is stored on exchange
        (, BionetTypes.Offer memory o) = exchange.getOffer(offerId);
        assertEq(offerId, o.id);
        assertEq(seller, o.seller);
        assertEq(price, o.price);
    }

    function testCommitWithVoid() public {
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        router.voidOffer(offerId);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert("Offer is void");
        makeCommit(price, offerId);
        vm.stopPrank();
    }

    function testExchangeGoodAfterVoid() public {
        // Voiding an offer doesn't effect past commits
        // seller creates offer
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // Buyer commits and escrows price
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // Seller decides to void offer (not deal)
        vm.startPrank(seller);
        router.voidOffer(offerId);
        vm.stopPrank();

        (, BionetTypes.Offer memory o) = exchange.getOffer(offerId);
        assertTrue(o.voided);

        // Exchange is still active...
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertTrue(exc.state == BionetTypes.ExchangeState.Committed);
        assertEq(exc.buyer, buyer);
    }

    function testCommitNoOffer() public {
        vm.startPrank(seller);
        vm.expectRevert("Offer doesn't exist");
        makeCommit(price, 101);
        vm.stopPrank();
    }

    function testZeroCaller() public {
        vm.startPrank(address(0x0));
        vm.expectRevert("Bad Address");
        createOffer(address(0x0), price, assetToken, assetTokenId);
        vm.stopPrank();
    }

    function testCommitWithLowPrice() public {
        // Buyer to commit with msg.value < price
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // Buyer has to commit with the price of the offer
        vm.startPrank(buyer);
        vm.expectRevert("Insufficient funds");
        makeCommit(price - 1 ether, offerId);
        vm.stopPrank();
    }

    function testGoodCommit() public {
        // seller creates offer
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // Buyer commits and escrows price
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
}
