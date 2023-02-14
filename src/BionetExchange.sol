// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetTypes.sol";
import "./BionetConstants.sol";
import "./libs/CountersLib.sol";
import "./libs/FundsLib.sol";
import "./interfaces/IBionetFunds.sol";
import "./interfaces/IBionetVoucher.sol";
import "./interfaces/IBionetExchange.sol";

import "openzeppelin/utils/Address.sol";
import "openzeppelin/token/ERC1155/IERC1155.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "openzeppelin/utils/introspection/ERC165Checker.sol";

import "forge-std/console2.sol";

contract BionetExchange is IBionetExchange, ReentrancyGuard {
    using Address for address payable;
    using CountersLib for CountersLib.Counter;
    CountersLib.Counter private _counter;

    address fundsAddress;
    address routerAddress;
    address voucherAddress;

    // offerid => offer
    mapping(uint256 => BionetTypes.Offer) offers;
    // exchangeid => exchange
    mapping(uint256 => BionetTypes.Exchange) exchanges;

    modifier onlyRouter() {
        require(msg.sender == routerAddress, UNAUTHORIZED_ACCESS);
        _;
    }

    constructor(
        address _router,
        address _funds,
        address _voucher
    ) {
        routerAddress = _router;
        fundsAddress = _funds;
        voucherAddress = _voucher;
    }

    function createOffer(address _caller, BionetTypes.Offer memory _offer)
        external
        onlyRouter
        nonReentrant
        returns (uint256)
    {
        // check for valid asset contract
        bool validAsset = ERC165Checker.supportsInterface(
            _offer.assetToken,
            type(IERC1155).interfaceId
        );
        require(validAsset, NOT_ASSET);

        // check the caller owns the asset
        uint256 num = IERC1155(_offer.assetToken).balanceOf(
            _caller,
            _offer.assetTokenId
        );
        require(num >= _offer.quantityAvailable, NOT_OWNER);

        uint256 oid = _counter.nextOfferId();
        _offer.id = oid;
        offers[oid] = _offer;

        emit OfferCreated(oid, _offer.seller, _offer);

        return oid;
    }

    function voidOffer(address _caller, uint256 _offerId) external onlyRouter {
        BionetTypes.Offer storage offer = getValidOffer(_offerId);
        require(_caller == offer.seller, "Not the seller of the offer");
        offer.voided = true;
        emit OfferVoided(_offerId, _caller);
    }

    function commit(address _buyer, uint256 _offerId)
        external
        payable
        onlyRouter
        nonReentrant
        returns (uint256)
    {
        // Check the offer exists and is not voided
        BionetTypes.Offer memory offer = getValidOffer(_offerId);
        require(msg.value >= offer.price, "Not enough money");

        // create the exchange
        uint256 eid = _counter.nextExchangeId();
        (, BionetTypes.Exchange storage exchange) = fetchExchange(eid);
        exchange.id = eid;
        exchange.offerId = _offerId;
        exchange.buyer = _buyer;
        exchange.redeemBy = block.timestamp + WEEK;
        exchange.state = BionetTypes.ExchangeState.Committed;

        // escrow the funds
        IBionetFunds(fundsAddress).encumberFunds{value: msg.value}(
            _buyer,
            msg.value,
            _offerId
        );

        // issue token to buyer
        IBionetVoucher(voucherAddress).issueVoucher(_buyer, eid);

        // TODO: Track time till redeemtion is due...

        // emit event
        emit OfferCommitted(_offerId, eid, _buyer);
        return eid;
    }

    function cancel(address _buyer, uint256 _exchangeId) external onlyRouter {
        (bool exists, BionetTypes.Exchange storage exchange) = fetchExchange(
            _exchangeId
        );
        require(exists, "Exchange does not exist");
        require(
            isValidExchangeState(
                exchange.state,
                BionetTypes.ExchangeState.Committed
            ),
            "Must be in committed state"
        );
        require(_buyer == exchange.buyer, BUYER_NOT_CALLER);

        // It doesn't matter if the voucher expired or not, still canceling...
        exchange.state = BionetTypes.ExchangeState.Canceled;
        exchange.finalizedDate = block.timestamp;

        BionetTypes.Offer memory offer = offers[exchange.offerId];

        // burn the voucher
        IBionetVoucher(voucherAddress).burnVoucher(exchange.id);

        // release funds
        IBionetFunds(fundsAddress).releaseFunds(
            exchange.id,
            offer.seller,
            exchange.buyer,
            offer.price,
            exchange.state
        );

        emit OfferCanceled(offer.id, exchange.id, exchange.buyer, false);
    }

    function revoke(address _caller, uint256 _exchangeId)
        external
        payable
        onlyRouter
        nonReentrant
    {
        (bool exists, BionetTypes.Exchange storage exchange) = fetchExchange(
            _exchangeId
        );
        require(exists, "Exchange does not exist");

        // check in a valid state
        require(
            isValidExchangeState(
                exchange.state,
                BionetTypes.ExchangeState.Committed
            ),
            "Must be in committed state"
        );

        BionetTypes.Offer memory offer = offers[exchange.offerId];
        // must be the seller
        require(_caller == offer.seller, SELLER_NOT_CALLER);

        // check if voucher expired
        bool voucherExpired = block.timestamp > exchange.redeemBy;
        if (voucherExpired) {
            // treat as a cancel. Buyer pays the penalty
            exchange.state = BionetTypes.ExchangeState.Canceled;
            exchange.finalizedDate = block.timestamp;

            // burn the voucher
            IBionetVoucher(voucherAddress).burnVoucher(exchange.id);

            IBionetFunds(fundsAddress).releaseFunds(
                exchange.id,
                offer.seller,
                exchange.buyer,
                offer.price,
                exchange.state
            );

            // reimburse money sent with this transaction
            if (msg.value > 0) payable(_caller).sendValue(msg.value);

            emit OfferCanceled(offer.id, exchange.id, exchange.buyer, true);
        } else {
            // do the revoke. Seller pays the penalty
            uint256 cost = FundsLib.calculateCost(
                offer.price,
                BionetTypes.ExchangeState.Revoked
            );
            require(msg.value >= cost, INSUFFICIENT_FUNDS);

            exchange.state = BionetTypes.ExchangeState.Revoked;
            exchange.finalizedDate = block.timestamp;

            // burn the voucher
            IBionetVoucher(voucherAddress).burnVoucher(exchange.id);

            // release funds
            IBionetFunds(fundsAddress).releaseFunds(
                exchange.id,
                offer.seller,
                exchange.buyer,
                offer.price,
                exchange.state
            );

            emit OfferRevoked(offer.id, _exchangeId, _caller);
        }
    }

    function redeem(address _buyer, uint256 _exchangeId) external onlyRouter {
        (bool exists, BionetTypes.Exchange storage exchange) = fetchExchange(
            _exchangeId
        );
        require(exists, "Exchange does not exist");

        // check in a valid state
        require(
            isValidExchangeState(
                exchange.state,
                BionetTypes.ExchangeState.Committed
            ),
            "Must be in committed state"
        );

        require(exchange.buyer == _buyer, BUYER_NOT_CALLER);

        BionetTypes.Offer memory offer = offers[exchange.offerId];

        bool voucherExpired = block.timestamp > exchange.redeemBy;
        if (voucherExpired) {
            // treat as a cancel. Buyer pays the penalty
            exchange.state = BionetTypes.ExchangeState.Canceled;
            exchange.finalizedDate = block.timestamp;

            // burn the voucher
            IBionetVoucher(voucherAddress).burnVoucher(exchange.id);

            // fine the buyer...
            IBionetFunds(fundsAddress).releaseFunds(
                exchange.id,
                offer.seller,
                exchange.buyer,
                offer.price,
                exchange.state
            );

            emit OfferCanceled(offer.id, exchange.id, exchange.buyer, true);
        } else {
            exchange.state = BionetTypes.ExchangeState.Redeemed;
            exchange.disputeBy = block.timestamp + WEEK;
            // burn the voucher
            IBionetVoucher(voucherAddress).burnVoucher(exchange.id);

            emit OfferRedeemed(
                offer.id,
                exchange.id,
                offer.seller,
                block.timestamp
            );
        }
    }

    function finalize() external {}

    /** Views **/

    function getOffer(uint256 _offerId)
        public
        view
        returns (bool exists, BionetTypes.Offer memory offer)
    {
        // TODO: replace with getValidOffer
        (exists, offer) = fetchOffer(_offerId);
    }

    function getExchange(uint256 _exchangeId)
        public
        view
        returns (bool exists, BionetTypes.Exchange memory exchange)
    {
        (exists, exchange) = fetchExchange(_exchangeId);
    }

    /** Internal */

    function fetchOffer(uint256 _offerId)
        internal
        view
        returns (bool exists, BionetTypes.Offer storage offer)
    {
        offer = offers[_offerId];
        exists = (offer.id > 0 && _offerId == offer.id);
    }

    function getValidOffer(uint256 _offerId)
        internal
        view
        returns (BionetTypes.Offer storage offer)
    {
        bool exists;
        (exists, offer) = fetchOffer(_offerId);
        require(exists, "Offer doesn't exist");
        require(!offer.voided, "Offer is void");
    }

    function fetchExchange(uint256 _exchangeId)
        internal
        view
        returns (bool exists, BionetTypes.Exchange storage exchange)
    {
        exchange = exchanges[_exchangeId];
        exists = (exchange.id > 0 && _exchangeId == exchange.id);
    }

    function getSellerFromExchange(uint256 _exchangeId)
        internal
        view
        returns (address seller)
    {
        BionetTypes.Exchange memory exchange = exchanges[_exchangeId];
        bool exists = (exchange.id > 0 && _exchangeId == exchange.id);
        require(exists, "Exchange does not exist");
        BionetTypes.Offer memory offer = offers[exchange.offerId];
        seller = offer.seller;
    }

    function isValidExchangeState(
        BionetTypes.ExchangeState _currentState,
        BionetTypes.ExchangeState _expectedState
    ) internal pure returns (bool) {
        return _currentState == _expectedState;
    }
}
