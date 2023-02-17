// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import "../src/libs/FundsLib.sol";
import "./helpers/BaseBionetTest.sol";

contract CommitRevokeTest is BaseBionetTest {
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

    function testGoodRevoke() public {
        // seller makes offer
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // Check the buyer has a voucher
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
        assertEq(sellerBal, revokeCost);

        uint256 buyerAfterRevoke = funds.getEscrowBalance(buyer);
        assertEq(buyerAfterRevoke, price + revokeCost);

        // Check state of exchange
        // revoked, finalized, voucher burnt...
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertTrue(exc.state == BionetTypes.ExchangeState.Revoked);
        assertTrue(exc.finalizedDate == block.timestamp);
        assertEq(voucher.balanceOf(exc.buyer), 0);
    }

    function testCantRevokeIfExpired() public {
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

        // state has changed
        // finalized timestamp
        // voucher burned
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertTrue(exc.state == BionetTypes.ExchangeState.Canceled);
        assertTrue(exc.finalizedDate == block.timestamp);
        assertEq(voucher.balanceOf(exc.buyer), 0);
    }

    function testCantRevokeIfLowCost() public {
        // seller makes offer
        vm.startPrank(seller);
        uint256 offerId = createOffer(seller, price, assetToken, assetTokenId);
        vm.stopPrank();

        // buyer commits
        vm.startPrank(buyer);
        uint256 exchangeId = makeCommit(price, offerId);
        vm.stopPrank();

        // seller revokes the deal. Calculate their cost to do so
        uint256 revokeCost = FundsLib.calculateCost(
            price,
            BionetTypes.ExchangeState.Revoked
        );

        // We intentionally reduce the amount sent...
        vm.startPrank(seller);
        vm.expectRevert("Insufficient funds");
        router.revoke{value: revokeCost - 0.0005 ether}(exchangeId);
        vm.stopPrank();

        // No state change
        (, BionetTypes.Exchange memory exc) = exchange.getExchange(exchangeId);
        assertTrue(exc.state == BionetTypes.ExchangeState.Committed);
    }
}
