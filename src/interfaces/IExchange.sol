// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import {IConfigurable} from "./IConfigurable.sol";

interface IExchange is IConfigurable {
    event Expired(address indexed exchange, uint256 when);
    event Committed(address indexed exchange, uint256 when);
    event Revoked(address indexed exchange, uint256 when);
    event Canceled(address indexed exchange, uint256 when);
    event Redeemed(address indexed exchange, uint256 when);
    event Completed(address indexed exchange, uint256 when);

    event ReleasedFunds(address indexed exchange);
    event WithdrawFunds(
        address indexed exchange,
        address indexed caller,
        uint256 amount
    );

    function initialize(
        address _factory,
        address payable _seller,
        address payable _buyer,
        address _asset,
        uint256[4] memory terms
    ) external payable;

    function commit() external payable;

    function cancel() external;

    function revoke() external;

    function redeem() external;

    function complete() external;

    function dispute() external;

    function withdraw() external;

    function escrowBalance(address _account) external returns (uint256);

    function triggerTimer() external;
}
