// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

/// @dev Maintains configuration information used in Exchange and
/// Factories.  Owned and controlled by the 'admin'.
interface IConfig {
    function setProtocolFee(uint256 _basisPoints) external;

    function getProtocolFee() external view returns (uint256 value);

    function setTreasury(address _tres) external;

    function getTreasury() external view returns (address value);

    function setExchangeTemplate(address _temp) external;

    function getExchangeTemplate() external view returns (address value);

    function calculateProtocolFee(
        uint256 _price
    ) external view returns (uint256 amount);
}
