// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import {ITreasury} from "./interfaces/ITreasury.sol";

import {Address} from "openzeppelin/utils/Address.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

/// @dev Hold Ether for the owner
contract BionetTreasury is ITreasury, Ownable {
    using Address for address payable;

    // Just consume ether...
    function deposit() external payable {
        emit FeeDeposit(msg.sender, msg.value);
    }

    function withdraw() external onlyOwner {
        uint256 bal = address(this).balance;
        payable(owner()).sendValue(bal);

        emit FeeWithdraw(msg.sender, bal);
    }
}
