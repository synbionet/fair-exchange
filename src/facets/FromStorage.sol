// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import {WithStorage} from "../libraries/LibStorage.sol";

/// @dev storage read helpers
contract FromStorage is WithStorage {
    function treasury() public view returns (address t) {
        t = bionetStore().treasury;
    }

    function usdc() public view returns (address t) {
        t = bionetStore().usdc;
    }

    function protocolFee() public view returns (uint256 t) {
        t = bionetStore().protocolFee;
    }
}
