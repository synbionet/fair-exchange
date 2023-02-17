// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetTypes.sol";
import "./libs/FundsLib.sol";
import {ExchangeStorage} from "./libs/ExchangeStorageLib.sol";
import "./BionetConstants.sol";
import "./interfaces/IBionetFunds.sol";
import "./interfaces/IBionetVoucher.sol";
import "./interfaces/IBionetExchange.sol";

import "openzeppelin/utils/Address.sol";
import "openzeppelin/token/ERC1155/IERC1155.sol";
import "openzeppelin/security/ReentrancyGuard.sol";

/**
 * @dev Core logic of Bionet
 */
contract BionetExchange is IBionetExchange, ReentrancyGuard {
    using Address for address payable;

    // Address of the Funds contract
    address fundsAddress;
    // Address of the Router
    address routerAddress;
    // Address of the Voucher
    address voucherAddress;

    modifier onlyRouter() {
        require(msg.sender == routerAddress, UNAUTHORIZED_ACCESS);
        _;
    }

    /**
     * @dev Called after default contructor to set needed addresses
     */
    function initialize(
        address _router,
        address _funds,
        address _voucher
    ) external {
        routerAddress = _router;
        fundsAddress = _funds;
        voucherAddress = _voucher;
    }

    /**
     * @dev See {IBionetExchange}
     *
     * Router does all basic validation
     *
     * Emits OfferCreated
     */
    function createOffer(BionetTypes.Offer memory _offer)
        external
        payable
        onlyRouter
        returns (uint256)
    {
        // Create the Offer
        uint256 oid = ExchangeStorage.nextOfferId();
        _offer.id = oid;
        ExchangeStorage.entities().offers[oid] = _offer;

        // Update seller's escrow
        ExchangeStorage.deposit(_offer.seller, msg.value);

        emit OfferCreated(oid, _offer.seller, _offer);
        return oid;
    }

    /**
     * @dev See {IBionetExchange}
     *
     * Sets the offer as voided, which should 'de-list' it on
     * the market. Emits OfferCreated
     *
     * Will revert if:
     *  - Caller is not the seller listed in the offer
     */
    function voidOffer(address _caller, uint256 _offerId) external onlyRouter {
        BionetTypes.Offer storage offer = ExchangeStorage.fetchValidOffer(
            _offerId
        );
        require(_caller == offer.seller, SELLER_NOT_CALLER);
        offer.voided = true;
        emit OfferVoided(_offerId, _caller);
    }

    /**
     * @dev See {IBionetExchange}
     *
     * Creates an Exchange between the buyer and seller. Escrows funds.
     * Issues a voucher to the buyer. Emits OfferCommitted.
     *
     * Will revert if:
     *  - Offer doesn't exist
     *  - Offer has been voided
     *  - The buyer doesn't send enough money for the price of the offer
     */
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
        require(msg.value >= offer.price, "Paid too low for offer");

        // create the exchange
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

    /**
     * See {IBionetExchange}
     *
     * Only the buyer can cancel.  Doing so is a penalty.  This
     * will release funds and emit an event
     *
     * Will revert if:
     *  - Exchange doesn't exist
     *  - Exchange is NOT in the committed state
     *  - Caller is not the exchange buyer
     */
    function cancel(address _buyer, uint256 _exchangeId) external onlyRouter {
        BionetTypes.Exchange storage exchange = ExchangeStorage
            .fetchValidExchange(_exchangeId);
        require(_buyer == exchange.buyer, BUYER_NOT_CALLER);
        require(
            exchange.state == BionetTypes.ExchangeState.Committed,
            "Not in committed state"
        );

        // It doesn't matter if the voucher expired or not, still canceling...
        // as the fee is the same
        exchange.state = BionetTypes.ExchangeState.Canceled;
        exchange.finalizedDate = block.timestamp;

        // Get some information from the offer needed to finalize.
        BionetTypes.Offer memory offer = ExchangeStorage.fetchOffer(
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

    /**
     * See {IBionetExchange}
     *
     * Called by seller to revoke a committment. Also checks
     * redeem timer and may cancel versus revoke if the timer
     * has expired.  If the timer has expired the seller is
     * reimbursed the msg.value sent.  Exchange must be in Committment state.
     *
     * Emits event
     *
     * Will revert if:
     *  - Exchange doesn't exist
     *  - Exchange is NOT in the committed state
     *  - Caller is not the seller
     */
    function revoke(address _caller, uint256 _exchangeId)
        external
        payable
        onlyRouter
        nonReentrant
    {
        BionetTypes.Exchange storage exchange = ExchangeStorage
            .fetchValidExchange(_exchangeId);
        require(
            exchange.state == BionetTypes.ExchangeState.Committed,
            "Not in committed state"
        );
        BionetTypes.Offer memory offer = ExchangeStorage.fetchOffer(
            exchange.offerId
        );
        require(_caller == offer.seller, SELLER_NOT_CALLER);

        // check if voucher expired (redeem period)
        bool voucherExpired = block.timestamp > exchange.redeemBy;
        if (voucherExpired) {
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

            // reimburse seller the money sent with this transaction
            if (msg.value > 0) payable(_caller).sendValue(msg.value);

            emit ExchangeCanceled(offer.id, exchange.id, exchange.buyer, true);
        } else {
            // do the revoke. Seller pays the penalty
            //uint256 cost = FundsLib.calculateCost(
            //    offer.price,
            //    BionetTypes.ExchangeState.Revoked
            //);
            //require(msg.value >= cost, INSUFFICIENT_FUNDS);

            exchange.state = BionetTypes.ExchangeState.Revoked;
            exchange.finalizedDate = block.timestamp;

            // escrow the funds. We need to move the ether to funds
            // REPLACE
            //IBionetFunds(fundsAddress).deposit{value: msg.value}(_caller);

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

    /**
     * @dev See {IBionetExchange}
     *
     * Called by buyer to redeem a voucher issued during commit.
     * If the voucher expired it's canceled by the protocol and
     * the buyer pays a penalty.  Otherwise we update state, burn the
     * voucher and start the dispute time.
     * Emit event.
     *
     * Will revert if:
     *  - Exchange doesn't exist
     *  - Exchange is NOT in the committed state
     *  - Caller is not the buyer
     */
    function redeem(address _buyer, uint256 _exchangeId) external onlyRouter {
        BionetTypes.Exchange storage exchange = ExchangeStorage
            .fetchValidExchange(_exchangeId);
        require(
            exchange.state == BionetTypes.ExchangeState.Committed,
            "Not in committed state"
        );
        require(exchange.buyer == _buyer, BUYER_NOT_CALLER);
        BionetTypes.Offer memory offer = ExchangeStorage.fetchOffer(
            exchange.offerId
        );

        bool voucherExpired = block.timestamp > exchange.redeemBy;
        if (voucherExpired) {
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

            emit ExchangeRedeemed(
                offer.id,
                exchange.id,
                offer.seller,
                block.timestamp
            );
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
     * Therefore any one can call finalize under the following conditions:
     * - The buyer is the caller, OR
     * - The dispute timer has expired
     *
     * In either case, the exchange will be closed.
     *
     * Emits event on successful close
     * Will revert if caller is not the buyer and the time has not expired
     */
    function finalize(address _buyer, uint256 _exchangeId) external onlyRouter {
        BionetTypes.Exchange storage exchange = ExchangeStorage
            .fetchValidExchange(_exchangeId);
        require(
            exchange.state == BionetTypes.ExchangeState.Redeemed,
            "Not in redeemed state"
        );

        bool disputeExpired = block.timestamp > exchange.disputeBy;
        if (_buyer == exchange.buyer || disputeExpired == true) {
            // wrap it up...
            BionetTypes.Offer memory offer = ExchangeStorage.entities().offers[
                exchange.offerId
            ];
            exchange.state = BionetTypes.ExchangeState.Completed;
            exchange.finalizedDate = block.timestamp;

            // IF the seller changed the approval for the exchange
            // to 'false', this will revert.  Which means the seller doesn't
            // get paid till they approve the exchange for xfer.
            IERC1155(offer.assetToken).safeTransferFrom(
                offer.seller,
                exchange.buyer,
                offer.assetTokenId,
                offer.quantityAvailable,
                ""
            );

            // release funds
            // REPLACE
            IBionetFunds(fundsAddress).releaseFunds(
                offer.seller,
                exchange.buyer,
                offer.price,
                BionetTypes.ExchangeState.Completed
            );

            emit ExchangeCompleted(offer.id, exchange.id, block.timestamp);
        } else {
            revert("Not authorized to finalize the exchange");
        }
    }

    function withdraw(address _account) external onlyRouter {
        uint256 amt = ExchangeStorage.withdraw(_account);
        payable(_account).sendValue(amt);
        // TODO: Emit event
    }

    /** Views **/

    /**
     * Get an Offer by ID
     */
    function getOffer(uint256 _offerId)
        public
        view
        returns (BionetTypes.Offer memory offer)
    {
        offer = ExchangeStorage.fetchOffer(_offerId);
    }

    /**
     * Get an Exchange by ID
     */
    function getExchange(uint256 _exchangeId)
        public
        view
        returns (BionetTypes.Exchange memory exchange)
    {
        exchange = ExchangeStorage.fetchValidExchange(_exchangeId);
    }

    /**
     * @dev Return the escrow balance of 'account'
     */
    function getEscrowBalance(address _account)
        external
        view
        returns (uint256 bal)
    {
        bal = ExchangeStorage.funds().escrow[_account];
    }

    /**
     * @dev Return the protocol balance
     */
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
        // burn the voucher
        IBionetVoucher(voucherAddress).burnVoucher(_exchangeId);

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

            // TODO:
            //emit ReleaseFunds(_seller, fee);
            // emit ReleaseFunds(_buyer, _price - fee);
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

            //emit ReleaseFunds(_buyer, _price + fee);
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

            //emit ReleaseFunds(_seller, _price - fee);
            // emit FeeCollected(fee);
        }
    }
}
