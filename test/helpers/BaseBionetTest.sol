// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/BionetRouter.sol";
import "../../src/BionetFunds.sol";
import "../../src/BionetExchange.sol";
import "../../src/BionetVoucher.sol";
import "../../src/BionetConstants.sol";

import "forge-std/Test.sol";
import "../mocks/MockAsset.sol";

contract BaseBionetTest is Test {
    BionetFunds funds;
    BionetRouter router;
    BionetExchange exchange;
    BionetVoucher voucher;

    MockAsset ipAsset;

    address seller = address(0x1100);

    uint256 public constant WALLET_FUNDING = 10 ether;

    function setUp() public virtual {
        // pre-computed addresses
        uint256 acctNonce = vm.getNonce(address(this));
        // router
        address ra = computeCreateAddress(address(this), acctNonce);
        // funds
        address fa = computeCreateAddress(address(this), acctNonce + 1);
        // voucher
        address va = computeCreateAddress(address(this), acctNonce + 2);
        // exchange
        address ea = computeCreateAddress(address(this), acctNonce + 3);

        // Note: deploy in the same order as the pre-computed addresses
        router = new BionetRouter(fa, ea);
        funds = new BionetFunds(ra, ea);
        voucher = new BionetVoucher(ra, ea);
        exchange = new BionetExchange(ra, fa, va);

        vm.deal(seller, WALLET_FUNDING);
        vm.startPrank(seller);
        ipAsset = new MockAsset();
        vm.stopPrank();
    }

    function createOffer(
        address _seller,
        uint256 _price,
        address _assetTokenAddress,
        uint256 _assetTokenId
    ) public returns (uint256 offerId) {
        BionetTypes.Offer memory o = mockOffer(
            _seller,
            _price,
            _assetTokenAddress,
            _assetTokenId
        );
        offerId = router.createOffer(o);
    }

    function makeCommit(uint256 _price, uint256 _offerId)
        public
        returns (uint256 exchangeId)
    {
        exchangeId = router.commit{value: _price}(_offerId);
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
