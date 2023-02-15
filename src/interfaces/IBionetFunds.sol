// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

/**
 * @dev Manages funds for the protocol
 *
 * For now we use Eth for simplicity.  We'll move to tokens in the future.
 *
 * Escrow is tracked by address.
 * Protocol balance is tracked and can only be withdrawn by the router owner (TODO)
 */
interface IBionetFunds {
    event DepositFunds(address indexed account, uint256 amount);
    event WithdrawFunds(address indexed account, uint256 amount);
    event ReleaseFunds(address indexed account, uint256 amount);
    event FeeCollected(uint256 amount);

    /**
     * @dev initialize with needed addresses
     */
    function initialize(address _router, address _exchange) external;

    /**
     * @dev Withdraw 'amount' from escrow
     */
    function withdraw(address _account) external;

    /**
     * @dev Deposit to escrow
     */
    function deposit(address _account) external payable;

    /**
     * @dev Release funds to parties
     */
    function releaseFunds(
        address _seller,
        address _buyer,
        uint256 _price,
        BionetTypes.ExchangeState _state
    ) external;

    /**
     * @dev Return the escrow balance of 'account'
     */
    function getEscrowBalance(address _account) external view returns (uint256);

    /**
     * @dev Return the protocol balance
     */
    function getProtocolBalance() external view returns (uint256);
}
