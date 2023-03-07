// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

/// Implemented by anyone that needs access to IConfig
interface IConfigurable {
    function config() external view returns (address configAddress);
}
