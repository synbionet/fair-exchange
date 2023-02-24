// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {IConfig} from "./interfaces/IConfig.sol";

import {Ownable} from "openzeppelin/access/Ownable.sol";

/// @dev Holds all configuration information for Exchanges.
/// Has an owner that can update values.
contract BionetConfig is IConfig, Ownable {
    uint256 feeBasisPoints; // e.g. 2% == 200

    address treasury;
    address exchangeTemplate;

    /// ***
    /// Setters (onlyOwner)
    /// ***

    function setProtocolFee(uint256 _basisPoints) external onlyOwner {
        feeBasisPoints = _basisPoints;
    }

    function setTreasury(address _tres) external onlyOwner {
        treasury = _tres;
    }

    function setExchangeTemplate(address _temp) external onlyOwner {
        exchangeTemplate = _temp;
    }

    function getProtocolFee() external view returns (uint256 value) {
        value = feeBasisPoints;
    }

    /// ***
    /// Getters
    /// ***

    function getTreasury() external view returns (address value) {
        value = treasury;
    }

    function getExchangeTemplate() external view returns (address value) {
        value = exchangeTemplate;
    }

    /// ***
    /// External helpers
    /// ***

    function calculateProtocolFee(uint256 _price)
        external
        view
        returns (uint256 amount)
    {
        amount = (_price * feeBasisPoints) / 10_000;
    }
}
