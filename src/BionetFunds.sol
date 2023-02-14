// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetTypes.sol";
import "./BionetConstants.sol";
import "./libs/FundsLib.sol";
import "./interfaces/IBionetFunds.sol";

import "openzeppelin/utils/Address.sol";

contract BionetFunds is IBionetFunds {
    using Address for address payable;

    address routerAddress;
    address exchangeAddress;

    // Escrow balance keyed by buyer/seller address
    mapping(address => uint256) escrow;
    // Balance of protocol fees collected
    uint256 protocolBalance;

    modifier onlyRouter() {
        require(msg.sender == routerAddress, UNAUTHORIZED_ACCESS);
        _;
    }

    modifier onlyExchange() {
        require(msg.sender == exchangeAddress, UNAUTHORIZED_ACCESS);
        _;
    }

    constructor(address _router, address _exchange) {
        routerAddress = _router;
        exchangeAddress = _exchange;
    }

    function withdraw(address _account, uint256 _amount) external onlyRouter {
        // TODO:  Talk to Exchange to determine how much the caller can wthdraw

        require(_amount > 0, MUST_BE_GT_ZERO);
        uint256 bal = getEscrowBalance(_account);
        require(bal >= _amount, INSUFFICIENT_FUNDS);

        decreaseEscrow(_account, _amount);
        payable(_account).sendValue(_amount);

        emit EscrowWithdraw(_account, _amount);
    }

    function encumberFunds(
        address _buyer,
        uint256 _price,
        uint256 _offerId
    ) external payable onlyExchange {
        require(msg.value >= _price, INSUFFICIENT_FUNDS);
        increaseEscrow(_buyer, msg.value);
        emit EscrowEncumbered(_buyer, _offerId, _price);
    }

    function releaseFunds(
        uint256 _exchangeId,
        address _seller,
        address _buyer,
        uint256 _price,
        BionetTypes.ExchangeState _state
    ) external onlyExchange {
        if (_state == BionetTypes.ExchangeState.Canceled) {
            // Canceled by buyer or protocol timeout
            uint256 fee = FundsLib.calculateFee(_price, CANCEL_REVOKE_FEE);
            // increase sellers escrow by 'fee'
            increaseEscrow(_seller, fee);
            // decrease buyers escrow by 'fee'
            decreaseEscrow(_buyer, fee);

            emit FundsReleased(_exchangeId, _seller, fee);
            emit FundsReleased(_exchangeId, _buyer, _price - fee);
        }

        if (_state == BionetTypes.ExchangeState.Revoked) {
            // by seller
            uint256 fee = FundsLib.calculateFee(_price, CANCEL_REVOKE_FEE);
            // increase buyers escrow by 'fee'
            increaseEscrow(_buyer, fee);
            emit FundsReleased(_exchangeId, _buyer, _price + fee);
        }

        if (_state == BionetTypes.ExchangeState.Completed) {
            // all good
            uint256 fee = FundsLib.calculateFee(_price, PROTOCOL_FEE);
            // increase protocol by 'fee'
            protocolBalance = protocolBalance + fee;
            // decrease buyers escrow by 'price'
            decreaseEscrow(_buyer, _price);
            // increase sellers escrow by 'price - fee'
            increaseEscrow(_seller, _price - fee);

            emit FundsReleased(_exchangeId, _seller, _price - fee);
            emit ProtocolFeeCollected(_exchangeId, fee);
        }
    }

    function getEscrowBalance(address _account)
        public
        view
        returns (uint256 bal)
    {
        bal = escrow[_account];
    }

    function getProtocolBalance() public view returns (uint256 bal) {
        bal = protocolBalance;
    }

    /***  Internal ***/

    function increaseEscrow(address account, uint256 _amount) internal {
        require(_amount > 0, VALUE_GT_ZERO);
        uint256 bal = escrow[account];
        escrow[account] = bal + _amount;
    }

    function decreaseEscrow(address account, uint256 _amount) internal {
        require(_amount > 0, VALUE_GT_ZERO);
        uint256 bal = escrow[account];
        require(bal >= _amount, INSUFFICIENT_FUNDS);
        unchecked {
            escrow[account] = bal - _amount;
        }
    }
}
