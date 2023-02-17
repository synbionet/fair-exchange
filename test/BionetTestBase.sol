// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/BionetRouter.sol";
import "../src/BionetExchange.sol";
import "../src/BionetVoucher.sol";
import "../src/BionetConstants.sol";

import "forge-std/Test.sol";
import "./mocks/MockAsset.sol";

contract BionetTestBase is Test {
    uint256 public constant WALLET_FUNDING = 10 ether;

    BionetRouter router;
    BionetExchange exchange;
    BionetVoucher voucher;
    MockAsset ipAsset;

    address payable buyer = payable(address(0x1100));
    address payable seller = payable(address(0x2200));

    function setUp() public virtual {
        router = new BionetRouter();
        voucher = new BionetVoucher();
        exchange = new BionetExchange();

        // Addresses
        address rA = address(router);
        address vA = address(voucher);
        address eA = address(exchange);

        router.initialize(eA);
        voucher.initialize(eA);
        exchange.initialize(rA, vA);

        vm.deal(seller, WALLET_FUNDING);
        vm.deal(buyer, WALLET_FUNDING);

        // Deploy and IP Asset the seller will offer
        // Approve the exchange to xfer
        vm.startPrank(seller);
        ipAsset = new MockAsset();
        ipAsset.setApprovalForAll(eA, true);
        vm.stopPrank();
    }

    /**
     * @dev Create and offer on behalf of seller.
     * Return the Offer ID
     */
    function _createOffer(uint256 offerPrice) internal returns (uint256 oid) {
        BionetTypes.Offer memory offer = mockOffer(
            seller,
            offerPrice,
            address(ipAsset),
            1
        );
        uint256 deposit = router.estimateSellerDeposit(offerPrice);
        vm.startPrank(seller);
        oid = router.createOffer{value: deposit}(offer);
        vm.stopPrank();
    }

    /**
     * @dev Create and offer on behalf of seller. Commit on behalf of buyer.
     * Return the (Offer ID, Exchange ID)
     */
    function _createOfferAndCommit(uint256 offerPrice)
        internal
        returns (uint256 oid, uint256 eid)
    {
        BionetTypes.Offer memory offer = mockOffer(
            seller,
            offerPrice,
            address(ipAsset),
            1
        );
        uint256 deposit = router.estimateSellerDeposit(offerPrice);
        vm.startPrank(seller);
        oid = router.createOffer{value: deposit}(offer);
        vm.stopPrank();

        vm.startPrank(buyer);
        eid = router.commit{value: offerPrice}(oid);
        vm.stopPrank();
    }

    function mockOffer(
        address _s,
        uint256 _p,
        address _at,
        uint256 _atid
    ) internal pure returns (BionetTypes.Offer memory offer) {
        offer = BionetTypes.Offer({
            id: 0,
            seller: _s,
            price: _p,
            quantityAvailable: 1,
            assetToken: _at,
            assetTokenId: _atid,
            metadataUri: "mock",
            voided: false
        });
    }
}
