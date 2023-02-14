// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

// Fees are fixed for MVP. Configurable in the future
// Fees use 'basis points'
uint256 constant PROTOCOL_FEE = 300; // 3%
uint256 constant CANCEL_REVOKE_FEE = 200; // 2%

// default redeem/dispute period
uint256 constant WEEK = 7 * 1 days;

// Access
string constant UNAUTHORIZED_ACCESS = "Unauthorized call";

// Offer
string constant SELLER_NOT_CALLER = "Seller must be the caller";
string constant BUYER_NOT_CALLER = "Buyer must be the caller";
string constant INVALID_PRICE = "Price cannot be below zero";
string constant INVALID_QTY = "Quanity available must be greater than zero";
string constant NOT_ASSET = "Not a valid asset contract";
string constant NOT_OWNER = "Cannot sell more than you own";

// Escrow
string constant VALUE_GT_ZERO = "Funds: value must be greater then zero";
string constant INSUFFICIENT_FUNDS = "Insufficient funds";

string constant MUST_BE_GT_ZERO = "Value must be greater than zero";

// offer related
string constant NO_OFFER = "Offer doesn't exist";
string constant INVALID_COMMIT_SELLER = "Seller can't buy own asset";
string constant BAD_VALUE_TRANSFER = "Wrong value transfered";
