// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetTypes.sol";
import "./BionetConstants.sol";
import {FundsLib} from "./libs/FundsLib.sol";
import {ExchangeStorage} from "./libs/ExchangeStorageLib.sol";
import {IBionetVoucher} from "./interfaces/IBionetVoucher.sol";
import {IBionetExchange} from "./interfaces/IBionetExchange.sol";

import {Address} from "openzeppelin/utils/Address.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

/// @dev Core logic of Bionet. Calls trigger state transistions
/// related to exchanges.  Where an exchange is committment
/// to an offer between a buyer and seller.
contract BionetExchange is IBionetExchange, ReentrancyGuard {
    using Address for address payable;

    // Address of the Router
    address routerAddress;
    // Address of the Voucher
    address voucherAddress;

    // msg.sender must be the address of the router
    modifier onlyRouter() {
        require(
            msg.sender == routerAddress,
            "Exchange: can only be called by the router"
        );
        _;
    }

    /// @dev Called right after constructor with address of
    /// dependency contracts.
    function initialize(address _router, address _voucher) external {
        routerAddress = _router;
        voucherAddress = _voucher;
    }

    /// @dev Called by a seller to create a new Offer.
    /// Each Offer has an id and associated information.
    /// Emits OfferCreated
    /// Will revert if:
    ///  - Caller is not the router
    /// Additional validation done at the router
    function createOffer(BionetTypes.Offer memory _offer)
        external
        payable
        onlyRouter
        returns (uint256)
    {
        // Create the Offer with an ID
        uint256 oid = ExchangeStorage.nextOfferId();
        _offer.id = oid;
        ExchangeStorage.entities().offers[oid] = _offer;

        // Move the funds sent with the transaction into
        // the seller's escrow
        ExchangeStorage.deposit(_offer.seller, msg.value);

        emit OfferCreated(oid, _offer.seller, _offer);
        return oid;
    }

    /// @dev Sets the offer as voided, which should 'de-list' it on
    /// the market. Emits OfferVoided
    /// Will revert if:
    ///  - Caller is not the router
    ///  - Caller is not the seller listed in the offer
    function voidOffer(address _caller, uint256 _offerId) external onlyRouter {
        BionetTypes.Offer storage offer = ExchangeStorage.fetchValidOffer(
            _offerId
        );
        require(_caller == offer.seller, "Exchange: caller must be the seller");
        offer.voided = true;

        emit OfferVoided(_offerId, _caller);
    }

    /// @dev Creates an Exchange between the buyer and seller. Escrows funds.
    /// Issues a voucher to the buyer. Emits OfferCommitted.
    /// Will revert if:
    ///  - Caller is not the router
    ///  - Offer doesn't exist
    ///  - Offer has been voided
    ///  - The buyer doesn't send enough money for the price of the offer
    function commit(address _buyer, uint256 _offerId)
        external
        payable
        onlyRouter
        returns (uint256)
    {
        // check the offer exists and is not voided. You cannot commit
        // to voided Offers
        BionetTypes.Offer memory offer = ExchangeStorage.fetchValidOffer(
            _offerId
        );
        require(
            msg.value >= offer.price,
            "Exchange: Value sent must be >= price"
        );

        // create the exchange with a new ID
        uint256 eid = ExchangeStorage.nextExchangeId();
        (, BionetTypes.Exchange storage exchange) = ExchangeStorage
            .fetchExchange(eid);

        exchange.id = eid;
        exchange.offerId = _offerId;
        exchange.buyer = _buyer;
        exchange.redeemBy = block.timestamp + WEEK; // Set the redeem timer
        exchange.state = BionetTypes.ExchangeState.Committed;

        // escrow funds
        ExchangeStorage.deposit(_buyer, msg.value);

        // issue token to buyer
        IBionetVoucher(voucherAddress).issueVoucher(_buyer, eid);

        // emit event
        emit ExchangeCreated(_offerId, eid, _buyer);
        return eid;
    }

    /// @dev Only the buyer can cancel.  Doing so is a penalty.  This
    /// will release funds and emit an event.  Cancel also happens if
    /// the 'redeemBy' timer expires.
    ///
    /// Will revert if:
    ///  - Caller is not the router
    ///  - Exchange doesn't exist
    ///  - Exchange is NOT in the committed state
    ///  - Caller is not the exchange buyer
    function cancel(address _buyer, uint256 _exchangeId) external onlyRouter {
        BionetTypes.Exchange storage exchange = ExchangeStorage
            .fetchValidExchange(_exchangeId);
        require(_buyer == exchange.buyer, "Exchange: Caller must be the buyer");
        require(
            exchange.state == BionetTypes.ExchangeState.Committed,
            "Exchange: Wrong state. Expected committed"
        );

        // It doesn't matter if the voucher expired or not, still canceling...
        // as the fee is the same
        exchange.state = BionetTypes.ExchangeState.Canceled;
        exchange.finalizedDate = block.timestamp;

        // Get some information from the offer needed to finalize.
        BionetTypes.Offer memory offer = ExchangeStorage.fetchValidOffer(
            exchange.offerId
        );
        finalizeCommittment(
            exchange.id,
            offer.seller,
            exchange.buyer,
            offer.price,
            exchange.state
        );

        emit ExchangeCanceled(offer.id, exchange.id, exchange.buyer, false);
    }

    /// @dev Called by seller to revoke a committment. Also checks
    /// redeem timer and may cancel versus revoke if the timer
    /// has expired.  Exchange must be in Committment state.
    ///
    /// Note: the seller can also call revoke without penalty
    /// if the redeem timer has expired. This will cause a cancel
    //  and the buyer pays the penalty.
    ///
    /// Emits ExchangeRevoked or ExchangeCanceled
    /// Will revert if:
    ///  - Caller is not the router
    ///  - Exchange doesn't exist
    ///  - Exchange is NOT in the committed state
    ///  - Caller is not the seller
    function revoke(address _caller, uint256 _exchangeId)
        external
        onlyRouter
        nonReentrant
    {
        BionetTypes.Exchange storage exchange = ExchangeStorage
            .fetchValidExchange(_exchangeId);
        require(
            exchange.state == BionetTypes.ExchangeState.Committed,
            "Exchange: Wrong state. Expected committed"
        );
        BionetTypes.Offer memory offer = ExchangeStorage.fetchValidOffer(
            exchange.offerId
        );
        require(_caller == offer.seller, "Exchange: Seller must be the caller");

        // check if voucher expired (redeem period)
        //bool voucherExpired = block.timestamp > exchange.redeemBy;
        if (redeemPhaseExpired(exchange)) {
            // treat as a cancel. Buyer pays the penalty
            exchange.state = BionetTypes.ExchangeState.Canceled;
            exchange.finalizedDate = block.timestamp;

            finalizeCommittment(
                exchange.id,
                offer.seller,
                exchange.buyer,
                offer.price,
                exchange.state
            );

            emit ExchangeCanceled(offer.id, exchange.id, exchange.buyer, true);
        } else {
            exchange.state = BionetTypes.ExchangeState.Revoked;
            exchange.finalizedDate = block.timestamp;

            finalizeCommittment(
                exchange.id,
                offer.seller,
                exchange.buyer,
                offer.price,
                exchange.state
            );

            emit ExchangeRevoked(offer.id, _exchangeId, _caller);
        }
    }

    /// @dev Called by buyer to redeem a voucher issued during commit phase.
    /// If the voucher expired it's canceled by the protocol and
    /// the buyer pays a penalty.  Otherwise we update state, burn the
    /// voucher and start the dispute time.
    /// Emits ExchangeRedeemed or ExchangeCanceled.
    /// Will revert if:
    ///  - Caller is not the router
    ///  - Exchange doesn't exist
    ///  - Exchange is NOT in the committed state
    ///  - Caller is not the buyer
    function redeem(address _buyer, uint256 _exchangeId) external onlyRouter {
        BionetTypes.Exchange storage exchange = ExchangeStorage
            .fetchValidExchange(_exchangeId);
        require(
            exchange.state == BionetTypes.ExchangeState.Committed,
            "Exchange: Wrong state. Expected committed"
        );
        require(exchange.buyer == _buyer, "Exchange: buyer must be the caller");
        BionetTypes.Offer memory offer = ExchangeStorage.fetchValidOffer(
            exchange.offerId
        );

        //bool voucherExpired = block.timestamp > exchange.redeemBy;
        if (redeemPhaseExpired(exchange)) {
            // treat as a cancel. Buyer pays the penalty
            exchange.state = BionetTypes.ExchangeState.Canceled;
            exchange.finalizedDate = block.timestamp;

            finalizeCommittment(
                exchange.id,
                offer.seller,
                exchange.buyer,
                offer.price,
                exchange.state
            );

            emit ExchangeCanceled(offer.id, exchange.id, exchange.buyer, true);
        } else {
            // Move to the redeemed state
            exchange.state = BionetTypes.ExchangeState.Redeemed;
            // Start the dispute timer
            exchange.disputeBy = block.timestamp + WEEK;

            // burn the voucher
            IBionetVoucher(voucherAddress).burnVoucher(exchange.id);

            emit ExchangeRedeemed(offer.id, exchange.id, offer.seller);
        }
    }

    /**
     * @dev Finalize an exchange.
     *
     * This is an important step in the process. It releases funds, and transfers
     * the IP NFT.  Exchange must be in the 'redeemed' state
     *
     * Possible scenarios:
     * 1. buyer calls to close -> all good, [completed]
     * 2. dispute timer expires -> [completed]
     *
     * Therefore anyone can call finalize under the following conditions:
     * - The buyer is the caller, OR
     * - The dispute timer has expired
     *
     * In either case, the exchange will be closed.
     *
     * Emits event on successful close
     * Will revert if caller is not the buyer and the time has not expired
     */

    /// @dev Finalize an exchange. This is an important step in the process. It releases funds, and transfers
    /// the IP NFT.  Exchange must be in the 'redeemed' state.
    ///
    /// Note: the seller can call finalize if the dispute timer has
    /// expired to release funds.
    ///
    /// Emits ExchangeCompleted
    /// @param _buyer for the exchange
    /// @param _exchangeId of the exchange
    function finalize(address _buyer, uint256 _exchangeId)
        external
        onlyRouter
        nonReentrant
    {
        BionetTypes.Exchange storage exchange = ExchangeStorage
            .fetchValidExchange(_exchangeId);
        require(
            exchange.state == BionetTypes.ExchangeState.Redeemed,
            "Exchange: Wrong state. Expected redeemed"
        );
        require(
            buyerOrDisputePhaseExpired(_buyer, exchange),
            "Exchange: buyer must be the caller or dispute phase expired"
        );

        // wrap it up...
        BionetTypes.Offer memory offer = ExchangeStorage.fetchValidOffer(
            exchange.offerId
        );
        exchange.state = BionetTypes.ExchangeState.Completed;
        exchange.finalizedDate = block.timestamp;

        // IF the seller removed the approval for the exchange
        // this will revert.  Which means the seller doesn't
        // get paid till they approve the exchange for xfer.
        IERC1155(offer.assetToken).safeTransferFrom(
            offer.seller,
            exchange.buyer,
            offer.assetTokenId,
            offer.quantityAvailable,
            ""
        );

        finalizeCommittment(
            exchange.id,
            offer.seller,
            exchange.buyer,
            offer.price,
            exchange.state
        );

        emit ExchangeCompleted(offer.id, exchange.id, block.timestamp);
    }

    /// @dev Withdraw funds (ether). Funds can only be withdrawn
    /// if they are release by the protocol.
    /// @param _account to withdraw from
    function withdraw(address _account) external onlyRouter {
        uint256 amt = ExchangeStorage.withdraw(_account);
        if (amt > 0) {
            payable(_account).sendValue(amt);
            emit Withdraw(_account, amt);
        }
    }

    /** Views **/

    /// @dev Get an Offer by ID
    function getOffer(uint256 _offerId)
        public
        view
        returns (bool exists, BionetTypes.Offer memory offer)
    {
        (exists, offer) = ExchangeStorage.fetchOffer(_offerId);
    }

    /// @dev Get an Exchange by ID
    function getExchange(uint256 _exchangeId)
        public
        view
        returns (bool exists, BionetTypes.Exchange memory exchange)
    {
        (exists, exchange) = ExchangeStorage.fetchExchange(_exchangeId);
    }

    /// @dev Return the escrow balance of 'account'
    function getEscrowBalance(address _account)
        external
        view
        returns (uint256 bal)
    {
        bal = ExchangeStorage.funds().escrow[_account];
    }

    /// @dev Return the protocol balance
    function getProtocolBalance() external view returns (uint256 bal) {
        bal = ExchangeStorage.funds().fees;
    }

    /** Internal */

    /**
     * Burns voucher and release funds based on the exchange state
     */
    function finalizeCommittment(
        uint256 _exchangeId,
        address _seller,
        address _buyer,
        uint256 _price,
        BionetTypes.ExchangeState _state
    ) internal {
        if (_state == BionetTypes.ExchangeState.Canceled) {
            // Canceled by buyer or protocol timeout
            // Calculate fee
            uint256 fee = FundsLib.calculateFee(_price, CANCEL_REVOKE_FEE);

            ExchangeStorage.transfer(_buyer, _seller, fee);

            // Buyer penalty
            uint256 refundLessPenalty = _price - fee;

            // Update amount available to withdraw
            // Seller gets the penalty fee
            ExchangeStorage.funds().availableToWithdraw[_seller] += fee;
            // Buyer gets price - fee back
            ExchangeStorage.funds().availableToWithdraw[
                _buyer
            ] += refundLessPenalty;

            // burn the voucher
            IBionetVoucher(voucherAddress).burnVoucher(_exchangeId);

            emit ReleaseEscrow(_seller, fee);
            emit ReleaseEscrow(_buyer, refundLessPenalty);
        }
        if (_state == BionetTypes.ExchangeState.Revoked) {
            // by seller
            uint256 fee = FundsLib.calculateFee(_price, CANCEL_REVOKE_FEE);
            // increase buyers escrow by 'fee'
            ExchangeStorage.transfer(_seller, _buyer, fee);
            // Seller penalty
            uint256 refundPlusPenalty = _price + fee;

            ExchangeStorage.funds().availableToWithdraw[
                _buyer
            ] += refundPlusPenalty;

            // burn the voucher
            IBionetVoucher(voucherAddress).burnVoucher(_exchangeId);

            emit ReleaseEscrow(_buyer, refundPlusPenalty);
        }
        if (_state == BionetTypes.ExchangeState.Completed) {
            // all good
            uint256 fee = FundsLib.calculateFee(_price, PROTOCOL_FEE);

            // Buyer pays the seller
            ExchangeStorage.transfer(_buyer, _seller, _price);
            // Seller pays protocol fee
            ExchangeStorage.transferFee(_seller, fee);

            uint256 avail = _price - fee;
            ExchangeStorage.funds().availableToWithdraw[_seller] += avail;

            emit ReleaseEscrow(_seller, avail);
            emit FeeCollected(_exchangeId, fee);
        }
    }

    /// @dev helper to check for redeem expiration (commit phase)
    function redeemPhaseExpired(BionetTypes.Exchange memory _exchange)
        internal
        view
        returns (bool result)
    {
        result = block.timestamp > _exchange.redeemBy;
    }

    /// @dev helper to check for dispute expiration (after redeem).
    /// check is the caller is the buyer OR the timer has expired.
    function buyerOrDisputePhaseExpired(
        address _buyer,
        BionetTypes.Exchange memory _exchange
    ) internal view returns (bool result) {
        result =
            _exchange.buyer == _buyer ||
            block.timestamp > _exchange.disputeBy;
    }
}
