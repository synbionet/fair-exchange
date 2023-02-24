// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {IConfigurable} from "./IConfigurable.sol";

interface IExchangeFactory is IConfigurable {
    event ExchangeCreated(
        address indexed location,
        address indexed seller,
        address indexed buyer,
        uint256 when
    );

    function createExchange(
        address payable _buyer,
        address _asset,
        uint256[4] memory terms
    ) external payable returns (address);

    function isExchange(address _contract) external view returns (bool result);
}
