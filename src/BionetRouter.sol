// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetTypes.sol";

import {FundsLib} from "./libs/FundsLib.sol";
import {IBionetRouter} from "./interfaces/IBionetRouter.sol";
import {IBionetVoucher} from "./interfaces/IBionetVoucher.sol";
import {IBionetExchange} from "./interfaces/IBionetExchange.sol";

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";
import {ERC165Checker} from "openzeppelin/utils/introspection/ERC165Checker.sol";

/// @dev Main entry way to the protocol. Acts as a proxy.
/// Primarily doing guard checks and forwarding the caller to
/// the Exchange. Contracts such as BionetExchange will only
/// allow calls from this contract.
contract BionetRouter is Ownable, IBionetRouter {
    // Address of BionetExchange
    address exchangeAddress;

    // Check for the zero address
    modifier noZeroAddress() {
        require(msg.sender != address(0x0), "Router: Zero address not allowed");
        _;
    }

    /// @dev Called after default contructor to set needed addresses
    /// @param _exchange address
    function initialize(address _exchange) external {
        exchangeAddress = _exchange;
    }

    /// @dev Withdraw ether from the exchange.  Withdraws will only
    /// send funds that have been released by the protocol.
    function withdraw() external noZeroAddress {
        IBionetExchange(exchangeAddress).withdraw(msg.sender);
    }

    /// @dev Return the escrow balance of the given account
    /// @param _account to check
    /// @return bal of the account
    function getEscrowBalance(address _account)
        external
        view
        noZeroAddress
        returns (uint256 bal)
    {
        bal = IBionetExchange(exchangeAddress).getEscrowBalance(_account);
    }

    /// @dev Get an exchange for the given ID
    /// @param _exchangeId of the exchange
    /// @return exists true if the exchange exists
    /// @return exchange information
    function getExchange(uint256 _exchangeId)
        external
        view
        returns (bool exists, BionetTypes.Exchange memory exchange)
    {
        (exists, exchange) = IBionetExchange(exchangeAddress).getExchange(
            _exchangeId
        );
    }

    /// @dev Get an offer for the given ID
    /// @param _offerId of the offer
    /// @return exists true if the offer exists
    /// @return offer information
    function getOffer(uint256 _offerId)
        external
        view
        returns (bool exists, BionetTypes.Offer memory offer)
    {
        (exists, offer) = IBionetExchange(exchangeAddress).getOffer(_offerId);
    }

    /// @dev Get the required deposit of a seller creating a new offer.
    /// @param _price to purchase the offer
    /// @return amt - the cost
    function getSellerDeposit(uint256 _price)
        external
        pure
        returns (uint256 amt)
    {
        amt = FundsLib.calculateSellerDeposit(_price);
    }

    /// @dev Get the balance of fees collected for the protocol
    /// @return bal - the balance
    function getProtocolBalance() external view returns (uint256 bal) {
        bal = IBionetExchange(exchangeAddress).getProtocolBalance();
    }

    /// @dev Create a new offer for a seller. The seller is expected
    /// to pay the appropriate deposit here.
    ///
    /// Can revert for several reasons.
    /// @param _offer information
    /// @return offerId of the offer
    function createOffer(BionetTypes.Offer memory _offer)
        external
        payable
        noZeroAddress
        returns (uint256 offerId)
    {
        // Make sure they sent the deposit
        uint256 deposit = FundsLib.calculateSellerDeposit(_offer.price);
        require(msg.value >= deposit, "Router: Insufficient seller deposit");
        // Do some validation on the offer
        require(
            _offer.seller == msg.sender,
            "Router: offer.seller must be the caller"
        );
        require(_offer.quantityAvailable > 0, "Router: offer qty > 0");
        require(
            _offer.assetToken != address(0x0),
            "Router: Asset token must have a valid address (not 0x0)"
        );
        require(_offer.voided == false, "Router: the offer cannot be voided");

        // Check the assetToken is an ERC1155 contract
        bool isValidAsset = ERC165Checker.supportsInterface(
            _offer.assetToken,
            type(IERC1155).interfaceId
        );
        require(isValidAsset, "Router: The asset is not an ERC1155 contract");

        // Check the seller owns at least the number (QTY) they're trying to sell
        uint256 numTokensOwned = IERC1155(_offer.assetToken).balanceOf(
            msg.sender,
            _offer.assetTokenId
        );
        require(
            numTokensOwned >= _offer.quantityAvailable,
            "Router: The seller does not own enough ERC1155 tokens for the offer qty"
        );

        // Check the seller has approved the exchange to transfer
        bool approvedForExchange = IERC1155(_offer.assetToken).isApprovedForAll(
            _offer.seller,
            exchangeAddress
        );
        require(
            approvedForExchange,
            "Router: The exchange must be approved to transfer your ERC1155 tokens"
        );

        // Have the exchange create and store it
        offerId = IBionetExchange(exchangeAddress).createOffer{
            value: msg.value
        }(_offer);
    }

    /// @dev Called by seller to void an offer. This should remove
    /// the offer from the market UI.  Will not impact
    /// existing exchanges against the offer.
    /// @param _offerId to void
    function voidOffer(uint256 _offerId) external noZeroAddress {
        IBionetExchange(exchangeAddress).voidOffer(msg.sender, _offerId);
    }

    /// @dev Commit to purchase. Creates a new exchange in the 'committed' state.
    /// Called by buyer. The buyer is expected to pay the price here.
    /// @param _offerId to commit to
    /// @return exchangeId of the new exchange
    function commit(uint256 _offerId)
        external
        payable
        noZeroAddress
        returns (uint256 exchangeId)
    {
        exchangeId = IBionetExchange(exchangeAddress).commit{value: msg.value}(
            msg.sender,
            _offerId
        );
    }

    /// @dev Cancel a committment. Called by the buyer. This will
    /// release funds to parties based on the fee schedule.
    /// @param _exchangeId of the exchange to cancel
    function cancel(uint256 _exchangeId) external noZeroAddress {
        IBionetExchange(exchangeAddress).cancel(msg.sender, _exchangeId);
    }

    /// @dev Revoke a committment. Called by the seller. This will
    /// release funds to parties based on the fee schedule.
    /// @param _exchangeId of the exchange to revoke
    function revoke(uint256 _exchangeId) external noZeroAddress {
        IBionetExchange(exchangeAddress).revoke(msg.sender, _exchangeId);
    }

    /// @dev Redeem a Voucher. Called by the buyer.  This signals to
    /// the seller that the buyer is ready for the asset.
    /// @param _exchangeId of the exchange to cancel
    function redeem(uint256 _exchangeId) external noZeroAddress {
        IBionetExchange(exchangeAddress).redeem(msg.sender, _exchangeId);
    }

    /// @dev Finalize the exchange. Usually means the buyer is happy.
    /// this will close out the exchange and release funds to the parties
    /// for withdrawal.
    /// @param _exchangeId of the exchange to cancel
    function finalize(uint256 _exchangeId) external noZeroAddress {
        IBionetExchange(exchangeAddress).finalize(msg.sender, _exchangeId);
    }
}
