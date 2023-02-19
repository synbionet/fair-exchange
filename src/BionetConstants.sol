// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

// *** Constant used across contracts ***

// Default redeem/dispute period
uint256 constant WEEK = 7 * 1 days;

// Fees are fixed for MVP. Configurable in the future. Use 'basis points'
uint256 constant PROTOCOL_FEE = 300; // 3%

uint256 constant CANCEL_REVOKE_FEE = 200; // 2%
