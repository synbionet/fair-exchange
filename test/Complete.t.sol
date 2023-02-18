// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import {FundsLib} from "../src/libs/FundsLib.sol";
import {BionetTestBase} from "./BionetTestBase.sol";
import {PROTOCOL_FEE, CANCEL_REVOKE_FEE, WEEK} from "../src/BionetConstants.sol";

import {MockAsset} from "./mocks/MockAsset.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";

/**
 */
contract CompleteTest is BionetTestBase {
    uint256 constant offerPrice = 1.5 ether;
    uint256 protocolFee;
    uint256 penaltyFee;

    struct Balances {
        uint256 eth;
        uint256 escrow;
    }

    function setUp() public virtual override {
        super.setUp();
        protocolFee = FundsLib.calculateFee(offerPrice, PROTOCOL_FEE);
        penaltyFee = FundsLib.calculateFee(offerPrice, CANCEL_REVOKE_FEE);
    }

    function test_buyer_complete() public {
        uint256 offerId;
        uint256 exchangeId;
        (offerId, exchangeId) = _createOfferAndCommit(offerPrice);
        (, BionetTypes.Offer memory offer) = exchange.getOffer(offerId);

        Balances memory bbb = _checkAllBalance(buyer);
        Balances memory sbb = _checkAllBalance(seller);
        uint256 pbb = exchange.getProtocolBalance();

        // Buyer has 'price' escrowed
        assertEq(bbb.escrow, offerPrice, "buyer's  escrow before");
        // Seller has 'fee' escrowed
        assertEq(sbb.escrow, penaltyFee, "seller's escrow before");

        // buyer calls finalize
        vm.startPrank(buyer);
        router.redeem(exchangeId);
        router.finalize(exchangeId);
        vm.stopPrank();

        // 1155 is transferred to buyer
        uint256 numTokensOwned = IERC1155(offer.assetToken).balanceOf(
            buyer,
            offer.assetTokenId
        );
        assertEq(numTokensOwned, 1, "buyer's owned assets");

        // Check all balances
        uint256 pba = exchange.getProtocolBalance();
        Balances memory bba = _checkAllBalance(buyer);
        Balances memory sba = _checkAllBalance(seller);

        // Protocol is paid
        assertEq(pbb + protocolFee, pba, "protocol fee after");

        // Buyer has transferred escrow to seller
        assertEq(bba.escrow, 0, "buyer's escrow after");

        // Seller's escrow balance is now price + penaltyFee - protocolFee
        assertEq(
            sba.escrow,
            offerPrice + penaltyFee - protocolFee,
            "seller's escrow after"
        );

        // Check withdraw ether

        // balance before
        uint256 bebb = buyer.balance;
        uint256 sebb = seller.balance;

        vm.startPrank(buyer);
        router.withdraw();
        vm.stopPrank();

        vm.startPrank(seller);
        router.withdraw();
        vm.stopPrank();

        // balance after
        uint256 beba = buyer.balance;
        uint256 seba = seller.balance;

        // Buyer had nothing to withdraw...
        assertEq(bebb, beba);

        // Seller gets paid!
        assertGt(seba, sebb);
    }

    function test_expired_anyone_can_complete() public {
        // All the same code as above except:
        // we fast-forward the blockchain
        // we have the seller call finalize.
        // Anyone can trigger a complete IF
        // the timer has expired
        uint256 offerId;
        uint256 exchangeId;
        (offerId, exchangeId) = _createOfferAndCommit(offerPrice);
        (, BionetTypes.Offer memory offer) = exchange.getOffer(offerId);

        Balances memory bbb = _checkAllBalance(buyer);
        Balances memory sbb = _checkAllBalance(seller);
        uint256 pbb = exchange.getProtocolBalance();

        // Buyer has 'price' escrowed
        assertEq(bbb.escrow, offerPrice, "buyer's  escrow before");
        // Seller has 'fee' escrowed
        assertEq(sbb.escrow, penaltyFee, "seller's escrow before");

        vm.startPrank(buyer);
        router.redeem(exchangeId);
        vm.stopPrank();

        // Fast forward to expire
        vm.warp(block.timestamp + WEEK + 1 days);
        // address(this) calls finalize
        router.finalize(exchangeId);

        // 1155 is transferred to buyer
        uint256 numTokensOwned = IERC1155(offer.assetToken).balanceOf(
            buyer,
            offer.assetTokenId
        );
        assertEq(numTokensOwned, 1, "buyer's owned assets");

        // Check all balances
        uint256 pba = exchange.getProtocolBalance();
        Balances memory bba = _checkAllBalance(buyer);
        Balances memory sba = _checkAllBalance(seller);

        // Protocol is paid
        assertEq(pbb + protocolFee, pba, "protocol fee after");

        // Buyer has transferred escrow to seller
        assertEq(bba.escrow, 0, "buyer's escrow after");

        // Seller's escrow balance is now price + penaltyFee - protocolFee
        assertEq(
            sba.escrow,
            offerPrice + penaltyFee - protocolFee,
            "seller's escrow after"
        );

        // Check withdraw ether

        // balance before
        uint256 bebb = buyer.balance;
        uint256 sebb = seller.balance;

        vm.startPrank(buyer);
        router.withdraw();
        vm.stopPrank();

        vm.startPrank(seller);
        router.withdraw();
        vm.stopPrank();

        // balance after
        uint256 beba = buyer.balance;
        uint256 seba = seller.balance;

        // Buyer had nothing to withdraw...
        assertEq(bebb, beba);

        // Seller gets paid!
        assertGt(seba, sebb);
    }

    function _checkAllBalance(address _account)
        internal
        view
        returns (Balances memory bal)
    {
        bal.eth = _account.balance;
        bal.escrow = router.getEscrowBalance(_account);
    }
}
