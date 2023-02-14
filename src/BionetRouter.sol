// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetTypes.sol";
import "./BionetConstants.sol";
import "./interfaces/IBionetFunds.sol";
import "./interfaces/IBionetRouter.sol";
import "./interfaces/IBionetVoucher.sol";
import "./interfaces/IBionetExchange.sol";

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC1155/IERC1155.sol";
import "openzeppelin/utils/introspection/ERC165Checker.sol";

/**
 * @dev Implementation of IBionetRouter.
 *
 * Acts as a proxy to the protocol. Primarily doing
 * guard checks and forwarding the caller to
 * the respective contract. Contracts such as BionetExchange
 * will only allow calls from this contract.
 */
contract BionetRouter is Ownable, IBionetRouter {
    // Address of BionetFunds
    address fundsAddress;
    // Address of BionetExchange
    address exchangeAddress;

    // Check for the zero address
    // TODO: Move message to constants
    modifier noZeroAddress() {
        require(msg.sender != address(0x0), BAD_ADDRESS);
        _;
    }

    /**
     * @dev Sets the required addresses of the funds and exchange contracts
     */
    constructor(address _funds, address _exchange) {
        fundsAddress = _funds;
        exchangeAddress = _exchange;
    }

    /**
     * @dev See {IBionetRouter}
     */
    function withdraw(uint256 _amount) external noZeroAddress {
        IBionetFunds(fundsAddress).withdraw(msg.sender, _amount);
    }

    /**
     * @dev See {IBionetRouter}
     */
    function escrowBalance(address _account)
        external
        view
        noZeroAddress
        returns (uint256 bal)
    {
        bal = IBionetFunds(fundsAddress).getEscrowBalance(_account);
    }

    /**
     * @dev Create a new offer for a seller.
     *
     * Will revert if:
     * - Seller doesn't match the caller
     * - ... need more
     */
    function createOffer(BionetTypes.Offer memory _offer)
        external
        noZeroAddress
        returns (uint256 offerId)
    {
        require(_offer.seller == msg.sender, SELLER_NOT_CALLER);
        require(_offer.quantityAvailable > 0, INVALID_QTY);
        require(_offer.assetToken != address(0x0), BAD_ADDRESS);
        require(_offer.voided == false, OFFER_VOIDED);

        // Check the assetToken is an ERC1155
        bool isValidAsset = ERC165Checker.supportsInterface(
            _offer.assetToken,
            type(IERC1155).interfaceId
        );
        require(isValidAsset, NOT_ASSET);

        // Check the seller owns at least the number they're trying to sell
        uint256 numTokensOwned = IERC1155(_offer.assetToken).balanceOf(
            msg.sender,
            _offer.assetTokenId
        );
        require(numTokensOwned >= _offer.quantityAvailable, NOT_OWNER);

        offerId = IBionetExchange(exchangeAddress).createOffer(_offer);
    }

    /**
     * @dev Called by seller to void an offer
     *
     * Will not impact existing exchanges against the offer.
     * See {BionetExchange}
     */
    function voidOffer(uint256 _offerId) external noZeroAddress {
        IBionetExchange(exchangeAddress).voidOffer(msg.sender, _offerId);
    }

    /**
     * @dev Commit to purchase
     *
     * Called by buyer
     */
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

    /**
     * @dev Cancel a committment
     *
     * Called by Buyer
     */
    function cancel(uint256 _exchangeId) external noZeroAddress {
        IBionetExchange(exchangeAddress).cancel(msg.sender, _exchangeId);
    }

    /**
     * @dev Revoke a committment
     *
     * Called by Seller
     */
    function revoke(uint256 _exchangeId) external payable noZeroAddress {
        IBionetExchange(exchangeAddress).revoke{value: msg.value}(
            msg.sender,
            _exchangeId
        );
    }

    /**
     * @dev Redeem a Voucher
     *
     * Called by Buyer
     */
    function redeem(uint256 _exchangeId) external noZeroAddress {
        IBionetExchange(exchangeAddress).redeem(msg.sender, _exchangeId);
    }
}
