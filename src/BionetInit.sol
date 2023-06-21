// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import {WithStorage} from "./libraries/LibStorage.sol";

import {IERC173} from "diamond/interfaces/IERC173.sol";
import {IERC165} from "diamond/interfaces/IERC165.sol";
import {LibDiamond} from "diamond/libraries/LibDiamond.sol";
import {IDiamondCut} from "diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "diamond/interfaces/IDiamondLoupe.sol";

struct InitArgs {
    address treasury;
    address usdc;
    uint256 protocolFee;
}

contract BionetInit is WithStorage {
    function init(InitArgs memory _args) external {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // Set counters to 1 for starters
        counters().nextExchangeId = 1;
        counters().nextServiceId = 1;

        bionetStore().usdc = _args.usdc;
        bionetStore().treasury = _args.treasury;
        bionetStore().protocolFee = _args.protocolFee;
    }
}
