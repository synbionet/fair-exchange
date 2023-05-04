// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

/// @dev Storage for the Exchange and helpers to access
/// data.
library ExchangeStorage {
    // Storage slots
    bytes32 internal constant FUNDS_POSITION =
        keccak256("fair-exchange.protocol.funds");
    bytes32 internal constant ENTITIES_POSITION =
        keccak256("fair-exchange.protocol.entities");
    bytes32 internal constant COUNTER_POSITION =
        keccak256("fair-exchange.protocol.counter");

    // Address used for protocol fees collected
    address internal constant PROTOCOL_FEE_ADDRESS = address(0x0);

    struct Counters {
        uint256 _offerId;
        uint256 _exchangeId;
    }

    struct Funds {
        // Escrow balance keyed by address
        mapping(address => uint256) escrow;
        // How much escrow has been released (can be withdrawn)
        mapping(address => uint256) availableToWithdraw;
        // Total fees
        uint256 fees;
        // Total escrow
        uint256 totalEscrow;
    }

    struct Entities {
        // offerid => offer
        mapping(uint256 => BionetTypes.Offer) offers;
        // exchangeid => exchange
        mapping(uint256 => BionetTypes.Exchange) exchanges;
    }

    // STORAGE ACCESS

    function counters() internal pure returns (Counters storage cs) {
        bytes32 pos = COUNTER_POSITION;
        assembly {
            cs.slot := pos
        }
    }

    function funds() internal pure returns (Funds storage fs) {
        bytes32 pos = COUNTER_POSITION;
        assembly {
            fs.slot := pos
        }
    }

    function entities() internal pure returns (Entities storage es) {
        bytes32 pos = COUNTER_POSITION;
        assembly {
            es.slot := pos
        }
    }

    // HELPERS

    function nextOfferId() internal returns (uint256 value) {
        counters()._offerId++;
        value = counters()._offerId;
    }

    function nextExchangeId() internal returns (uint256 value) {
        counters()._exchangeId++;
        value = counters()._exchangeId;
    }

    /// @dev Get an Offer by Id
    /// Reverts if:
    function fetchOffer(uint256 _offerId)
        internal
        view
        returns (bool exists, BionetTypes.Offer storage offer)
    {
        offer = entities().offers[_offerId];
        exists = (offer.id > 0 && _offerId == offer.id);
    }

    /// @dev Get an Offer by Id with reverts
    function fetchValidOffer(uint256 _offerId)
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
        exchange = entities().exchanges[_exchangeId];
        exists = (exchange.id > 0 && _exchangeId == exchange.id);
    }

    function fetchValidExchange(uint256 _exchangeId)
        internal
        view
        returns (BionetTypes.Exchange storage exchange)
    {
        bool exists;
        exchange = entities().exchanges[_exchangeId];
        (exists, exchange) = fetchExchange(_exchangeId);
        require(exists, "Exchange doesn't exist");
    }

    function deposit(address _account, uint256 _amount) internal {
        funds().escrow[_account] += _amount;
        funds().totalEscrow += _amount;
    }

    function withdraw(address _account) internal returns (uint256 amount) {
        amount = funds().availableToWithdraw[_account];
        uint256 bal = funds().escrow[_account];
        require(bal >= amount, "Insufficient funds!");
        funds().escrow[_account] -= amount;
        funds().availableToWithdraw[_account] -= amount;
        funds().totalEscrow -= amount;
    }

    function transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        require(funds().escrow[_from] >= _amount, "Insufficient funds");
        funds().escrow[_from] -= _amount;
        funds().escrow[_to] += _amount;
    }

    function transferFee(address _from, uint256 _amount) internal {
        require(funds().escrow[_from] >= _amount, "Insufficient funds");
        funds().escrow[_from] -= _amount;
        funds().fees += _amount;
    }
}
