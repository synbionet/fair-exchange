// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

/// @dev Common errors shared across Facets

/// thrown when there's a zero address
error NoZeroAddress();

/// thrown when the called is unauthorized
error UnAuthorizedCaller();

/// thrown when you try to float a bad check
error InsufficientFunds();

/// thrown when a service is not found or doesn't
/// match the exchange
error MissingOrInvalidService();
