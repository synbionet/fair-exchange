// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetTypes.sol";
import "./BionetConstants.sol";
import "./interfaces/IBionetFunds.sol";
import "./interfaces/IBionetRouter.sol";
import "./interfaces/IBionetVoucher.sol";
import "./interfaces/IBionetExchange.sol";

import "openzeppelin/access/Ownable.sol";

contract BionetRouter is Ownable, IBionetRouter {
    address fundsAddress;
    address exchangeAddress;

    modifier noZeroAddress() {
        require(msg.sender != address(0x0), "Bad caller address");
        _;
    }

    constructor(address _funds, address _exchange) {
        fundsAddress = _funds;
        exchangeAddress = _exchange;
    }

    function withdraw(uint256 _amount) external noZeroAddress {
        IBionetFunds(fundsAddress).withdraw(msg.sender, _amount);
    }

    function escrowBalance(address _account)
        external
        view
        noZeroAddress
        returns (uint256 bal)
    {
        bal = IBionetFunds(fundsAddress).getEscrowBalance(_account);
    }

    function createOffer(BionetTypes.Offer memory _offer)
        external
        noZeroAddress
        returns (uint256 offerId)
    {
        require(_offer.seller == msg.sender, SELLER_NOT_CALLER);
        require(_offer.price >= 0, INVALID_PRICE);
        require(_offer.quantityAvailable > 0, INVALID_QTY);

        offerId = IBionetExchange(exchangeAddress).createOffer(
            msg.sender,
            _offer
        );
    }

    function voidOffer(uint256 _offerId) external noZeroAddress {
        IBionetExchange(exchangeAddress).voidOffer(msg.sender, _offerId);
    }

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

    function cancel(uint256 _exchangeId) external noZeroAddress {
        IBionetExchange(exchangeAddress).cancel(msg.sender, _exchangeId);
    }

    function revoke(uint256 _exchangeId) external payable noZeroAddress {
        IBionetExchange(exchangeAddress).revoke{value: msg.value}(
            msg.sender,
            _exchangeId
        );
    }

    function redeem(uint256 _exchangeId) external noZeroAddress {
        IBionetExchange(exchangeAddress).redeem(msg.sender, _exchangeId);
    }
}
