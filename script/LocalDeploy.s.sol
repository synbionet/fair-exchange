// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Script.sol";

import {SimBase} from "../simulation/SimBase.sol";

contract LocalDeployScript is SimBase {
    function setUp() public {
        _setUpActors();
    }

    function run() public {
        _deployBaseContracts();
    }
}
