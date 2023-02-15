// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetTypes.sol";
import "./BionetConstants.sol";
import "./libs/FundsLib.sol";
import "./interfaces/IBionetFunds.sol";

import "openzeppelin/utils/Address.sol";

/**
 * Manage funds for the protocol.  Maintains escrow and protocol fees.
 * Uses ether vs token (for now).
 *
 */
contract BionetFunds is IBionetFunds {
    using Address for address payable;

    // Address of the router
    address routerAddress;
    // Address of the exchange
    address exchangeAddress;
    // Balance of fees collected
    uint256 protocolBalance;
    // Escrow balance keyed by address
    mapping(address => uint256) escrow;
    // How much escrow has been released (can be withdrawn)
    mapping(address => uint256) availableToWithdraw;

    modifier onlyRouter() {
        require(msg.sender == routerAddress, UNAUTHORIZED_ACCESS);
        _;
    }

    modifier onlyExchange() {
        require(msg.sender == exchangeAddress, UNAUTHORIZED_ACCESS);
        _;
    }

    /**
     * @dev Called after default contructor to set needed addresses
     */
    function initialize(address _router, address _exchange) external {
        routerAddress = _router;
        exchangeAddress = _exchange;
    }

    function deposit(address _account) external payable onlyExchange {
        increaseEscrow(_account, msg.value);
        emit DepositFunds(_account, msg.value);
    }

    /**
     * @dev See {IBionetFunds}
     *
     * Decrease escrow balance and send 'amount' to the 'account'
     *
     * Will revert if:
     *  - amount requested is > escrow balance
     *
     * Emits Event
     */
    function withdraw(address _account) external onlyRouter {
        uint256 amount = availableToWithdraw[_account];
        if (amount > 0) {
            decreaseEscrow(_account, amount);
            payable(_account).sendValue(amount);
            emit WithdrawFunds(_account, amount);
        }
    }

    /**
     * @dev See {IBionetFunds}
     *
     * Releases funds to parties based in the current exchange state. Calculates
     * fees and adjusts escrow as needed.
     *
     * Currently only releases funds for 3 states: Cancel, Revoke, Complete.
     * More will be added.
     *
     * Emits Events
     */
    function releaseFunds(
        address _seller,
        address _buyer,
        uint256 _price,
        BionetTypes.ExchangeState _state
    ) external onlyExchange {
        if (_state == BionetTypes.ExchangeState.Canceled) {
            // Canceled by buyer or protocol timeout

            // Calculate fee
            uint256 fee = FundsLib.calculateFee(_price, CANCEL_REVOKE_FEE);
            // Increase sellers escrow by 'fee'
            increaseEscrow(_seller, fee);
            // Decrease buyers escrow by 'fee'
            decreaseEscrow(_buyer, fee);

            // Update amount available to withdraw
            availableToWithdraw[_seller] += fee;
            availableToWithdraw[_buyer] += (_price - fee);

            emit ReleaseFunds(_seller, fee);
            emit ReleaseFunds(_buyer, _price - fee);
        }

        if (_state == BionetTypes.ExchangeState.Revoked) {
            // by seller
            uint256 fee = FundsLib.calculateFee(_price, CANCEL_REVOKE_FEE);
            // increase buyers escrow by 'fee'
            increaseEscrow(_buyer, fee);
            availableToWithdraw[_buyer] += (_price + fee);

            emit ReleaseFunds(_buyer, _price + fee);
        }

        if (_state == BionetTypes.ExchangeState.Completed) {
            // all good
            uint256 fee = FundsLib.calculateFee(_price, PROTOCOL_FEE);
            // increase protocol by 'fee'
            protocolBalance += fee;
            // decrease buyers escrow by 'price'
            decreaseEscrow(_buyer, _price);

            // increase sellers escrow by 'price - fee'
            increaseEscrow(_seller, _price - fee);
            availableToWithdraw[_seller] += (_price - fee);

            emit ReleaseFunds(_seller, _price - fee);
            emit FeeCollected(fee);
        }
    }

    // Catch ether accidently sent to contract
    fallback() external payable {
        // goes to protocol fee
        protocolBalance += msg.value;
    }

    // Receive ether sent to the contract's address
    receive() external payable {
        // goes to protocol fee
        protocolBalance += msg.value;
    }

    /**
     * @dev See {IBionetFunds}
     */
    function getEscrowBalance(address _account)
        public
        view
        returns (uint256 bal)
    {
        bal = escrow[_account];
    }

    /**
     * @dev See {IBionetFunds}
     */
    function getProtocolBalance() public view returns (uint256 bal) {
        bal = protocolBalance;
    }

    /***  Internal ***/

    function increaseEscrow(address account, uint256 _amount) internal {
        escrow[account] += _amount;
    }

    function decreaseEscrow(address account, uint256 _amount) internal {
        require(escrow[account] >= _amount, INSUFFICIENT_FUNDS);
        escrow[account] -= _amount;
    }
}
