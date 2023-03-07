// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

interface ITreasury {
    event FeeDeposit(address indexed from, uint256 amount);
    event FeeWithdraw(address indexed to, uint256 amount);

    function deposit() external payable;

    function withdraw() external;
}
