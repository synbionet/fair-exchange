// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

/**
 * @dev Manages funds for the protocol
 *
 * For now we only use Eth for simplicity.  We'll move to tokens in the future.
 *
 * Escrow is tracked by address.
 * Protocol balance is tracked and can only be withdrawn by the router owner (TODO)
 */
interface IBionetFunds {
    //event EscrowDeposit(address indexed account, uint256 amount);
    /**
     * @dev Emitted when the 'account' is withdraw 'amount' from escrow
     */
    event EscrowWithdraw(address indexed account, uint256 amount);

    /**
     * @dev Emitted when the 'buyer' has escrowed the 'amount' for an offer
     */
    event EscrowEncumbered(
        address indexed buyer,
        uint256 indexed offerid,
        uint256 amount
    );
    /**
     * @dev Emitted when the exchange is release 'amount' of funds to the 'receiver'
     */
    event FundsReleased(
        uint256 indexed _exchangeId,
        address indexed receiver,
        uint256 amount
    );

    /**
     * @dev Emitted when the protocol has collect 'amount' for an exchange
     */
    event ProtocolFeeCollected(uint256 indexed _exchangeId, uint256 amount);

    /**
     * @dev Withdraw 'amount' from escrow
     */
    function withdraw(address _account, uint256 _amount) external;

    /**
     * @dev Commit funds to escrow for a new exchange
     */
    function encumberFunds(
        address _buyer,
        uint256 _price,
        uint256 _offerId
    ) external payable;

    /**
     * @dev Release funds to parties
     */
    function releaseFunds(
        uint256 _exchangeId,
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
