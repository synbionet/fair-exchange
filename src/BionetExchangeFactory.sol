// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import {IConfig} from "./interfaces/IConfig.sol";
import {BionetExchange} from "./BionetExchange.sol";
import {IExchangeFactory} from "./interfaces/IExchangeFactory.sol";

import {Clones} from "openzeppelin/proxy/Clones.sol";

/// @dev Create an exchange for the seller
contract BionetExchangeFactory is IExchangeFactory {
    address public immutable config; /// address of the BionetConfig contract
    mapping(address => bool) validExchange;

    constructor(address _config) {
        require(
            _config != address(0x0),
            "ExchangeFactory: Zero address not allowed"
        );
        config = _config;
    }

    /// @dev Create an Exchange
    function createExchange(
        address payable _buyer,
        address _asset,
        uint256[4] memory _terms
    ) external payable returns (address exchangeAddress) {
        // validate input
        _validate(_buyer, _asset, _terms);

        address payable sender = payable(msg.sender);

        emit ExchangeCreated(exchangeAddress, sender, _buyer, block.timestamp);

        validExchange[
            exchangeAddress = _createInstance(sender, _buyer, _asset, _terms)
        ] = true;
    }

    function isExchange(address _contract) external view returns (bool result) {
        result = validExchange[_contract];
    }

    function _createInstance(
        address payable _seller,
        address payable _buyer,
        address _asset,
        uint256[4] memory _terms
    ) internal returns (address e) {
        address template = IConfig(config).getExchangeTemplate();

        e = Clones.clone(template);
        BionetExchange(e).initialize{value: msg.value}(
            address(this),
            _seller,
            _buyer,
            _asset,
            _terms
        );
    }

    /// @dev Validate inputs.  We validate input to a new Exchange here
    /// so we can avoid creating contracts with bad data.
    function _validate(
        address payable _buyer,
        address _asset,
        uint256[4] memory _terms
    ) internal view {
        require(
            msg.sender != address(0x0) &&
                _buyer != address(0x0) &&
                _asset != address(0x0),
            "ExchangeFactory: Zero address not allowed"
        );

        require(
            msg.value >= _terms[2],
            "ExchangeFactory: Seller deposit requiried"
        );

        // TODO: Validate 'asset' is contract of a type.
    }
}
