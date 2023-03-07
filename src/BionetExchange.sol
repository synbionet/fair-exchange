// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import {IConfig} from "./interfaces/IConfig.sol";
import {IExchange} from "./interfaces/IExchange.sol";
import {ITreasury} from "./interfaces/ITreasury.sol";
import {BionetExchangeStorage} from "./BionetExchangeStorage.sol";
import {IExchangeFactory} from "./interfaces/IExchangeFactory.sol";

import {Address} from "openzeppelin/utils/Address.sol";

/// @dev An implementation of a fair exchange state machine.
/// Represents a contract between two parties that are agreeing to 'terms'.
/// One of the goals of the contract is to incentivize parties to follow
/// the contract through rewards/penalties. Expiration timers are used
/// to help ensure the protocol is not locked in a state due to a single parties actions.
/// Timers are also used to give time to parties to coordinate activities
/// off-chain.
contract BionetExchange is IExchange, BionetExchangeStorage {
    using Address for address payable;

    function config() public view returns (address configAddress) {
        configAddress = IExchangeFactory(factory).config();
    }

    /// @dev Initialize a new Exchange with terms between a buyer and seller.
    /// Should be called by the factory.
    ///
    /// Reverts if:
    /// * There's a zero address for seller, buyer, or asset
    /// * Sender did not send the required seller's deposit
    ///
    /// @param _factory that created me
    /// @param _seller creating the exchange
    /// @param _buyer in the exchange
    /// @param _asset the seller is offering
    /// @param _terms an array of uint256 values:
    ///         [0]: tokenId of the asset offered
    ///         [1]: price
    ///         [2]: the seller's deposit (may be 0)
    ///         [3]: the buyer's penalty (may be 0)
    ///
    /// Note: Factory validates input before creating the Exchange.
    ///
    function initialize(
        address _factory,
        address payable _seller,
        address payable _buyer,
        address _asset,
        uint256[4] memory _terms
    ) external payable {
        seller = _seller;
        buyer = _buyer;
        asset = _asset;

        assetTokeId = _terms[0];
        price = _terms[1];
        sellerDeposit = _terms[2];
        buyerPenalty = _terms[3];

        // escrow sellers funds
        balanceOf[seller] = sellerDeposit;
        totalEscrow += sellerDeposit;

        commitBy = ONE_WEEK; // TODO: make configurable?
        currentState = State.Init;
        isAvailableToWithdraw = false; // being explicit

        factory = _factory;
    }

    // ***
    // External
    // ***

    /// @dev Buyer commits to the terms starting the process and
    /// the redemption period timer.
    function commit() external payable onlyBuyer isValidState(State.Init) {
        // Check if the buyer has commited to the deal within the
        // required time, otherwise the deal expires; seller gets
        // their deposit back, buyer is refunded msg.value.
        if (_commitByTimerExpired()) {
            finalizedDate = block.timestamp;
            currentState = State.Expired;
            _releaseEscrow();

            emit Expired(address(this), block.timestamp);
            emit ReleasedFunds(address(this));

            payable(msg.sender).sendValue(msg.value);
        } else {
            uint256 buyerTotal = price + buyerPenalty;
            require(msg.value >= buyerTotal, "Exchange: Wrong deposit amount");

            // set buyers escrow
            balanceOf[buyer] = buyerTotal;
            totalEscrow += buyerTotal;

            // Update state and start redeem timer
            currentState = State.Committed;
            redeemBy = block.timestamp + ONE_WEEK;

            emit Committed(address(this), block.timestamp);
        }
    }

    /// @dev Buyer can cancel the deal. This may result in a penalty
    /// to the buyer depending on the terms
    function cancel() external onlyBuyer isValidState(State.Committed) {
        // Ignore the timer here. Outcome is the same
        _cancelInternal();
    }

    /// @dev Seller may revoke the deal. This may result in a penalty
    /// to the seller depending on the agreed upon terms.
    function revoke() external onlySeller isValidState(State.Committed) {
        // If the timer expired and the seller is trying to revoke,
        // we cancel it. Because the buyer has done nothing, they pay the penalty.
        if (_redeemByTimerExpired()) {
            _cancelInternal();
        } else {
            currentState = State.Revoked;
            finalizedDate = block.timestamp;

            _releaseEscrow();

            emit Revoked(address(this), block.timestamp);
            emit ReleasedFunds(address(this));
        }
    }

    /// @dev Called by the buyer to redeem to contract.  Redeem
    /// is use to signal to the seller the buyer is ready to receive
    /// the product.  It also start the dispute timer.  During this
    /// time the buyer may 'complete' the deal, or dispute it.
    function redeem() external onlyBuyer isValidState(State.Committed) {
        // If the buyer waited to long they pay the penalty. And the deal
        // is canceled
        if (_redeemByTimerExpired()) {
            _cancelInternal();
        } else {
            currentState = State.Redeemed;
            disputeBy = block.timestamp + ONE_WEEK;

            emit Redeemed(address(this), block.timestamp);
        }
    }

    /// @dev Called by the buyer to close the deal. Meaning everyone
    /// is happy.  The buyer got the product and the seller is paid.
    /// Both parties will be refunded for and deposits they made.
    /// The seller will pay a fee to the protocol for the proceeds
    /// of the sale.  If the buyer does nothing during the dispute
    /// timer the protocol automatically moves to this state.
    function complete() external onlyBuyer isValidState(State.Redeemed) {
        // Ignore the timer here, outcome is the same.
        _completeInternal();
    }

    /// @dev Seller can call this to trigger timers if nothing has happened.
    /// This is a safety mechanism to in the event the buyer does nothing.
    /// Smart Contracts timers are only activatied by external transactions.
    function triggerTimer() external onlySeller {
        if (currentState == State.Init && _commitByTimerExpired()) {
            finalizedDate = block.timestamp;
            currentState = State.Expired;
            _releaseEscrow();
            emit Expired(address(this), block.timestamp);
            emit ReleasedFunds(address(this));
        } else if (currentState == State.Committed && _redeemByTimerExpired()) {
            _cancelInternal();
        } else if (currentState == State.Redeemed && _disputeByTimerExpired()) {
            _completeInternal();
        }
    }

    /// TODO:
    function dispute() external onlyBuyer {}

    /// @dev Withdraw funds. Can be called by either the buyer or seller
    /// to withdraw and funds escrowed.  Funds are only released by the
    /// protocol based on the current state.
    function withdraw() external buyerOrSeller {
        require(
            isAvailableToWithdraw,
            "Exchange: Funds are not yet available to withdraw"
        );
        uint256 amt = balanceOf[msg.sender];
        if (amt > 0) {
            balanceOf[msg.sender] = 0;
            totalEscrow -= amt;
            emit WithdrawFunds(address(this), msg.sender, amt);
            payable(msg.sender).sendValue(amt);
        }
    }

    /// @dev What's the escrow balance of the 'account'
    function escrowBalance(
        address _account
    ) external view returns (uint256 bal) {
        bal = balanceOf[_account];
    }

    // ***
    // Guards
    // ***

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Exchange: expected the buyer");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Exchange: expected the seller");
        _;
    }

    modifier buyerOrSeller() {
        bool ok = msg.sender == buyer || msg.sender == seller;
        require(ok, "Exchange: expected the buyer or seller");
        _;
    }

    modifier isValidState(State _expected) {
        require(
            currentState == _expected,
            "Exchange: Invalid call for the current state"
        );
        _;
    }

    // ***
    // Internal stuff
    // ***

    function _commitByTimerExpired() internal view returns (bool expired) {
        expired = block.timestamp > commitBy;
    }

    function _redeemByTimerExpired() internal view returns (bool expired) {
        expired = block.timestamp > redeemBy;
    }

    function _disputeByTimerExpired() internal view returns (bool expired) {
        expired = block.timestamp > disputeBy;
    }

    /// @dev Cancel logic is used in a few states including trigger
    function _cancelInternal() internal {
        currentState = State.Canceled;
        finalizedDate = block.timestamp;
        _releaseEscrow();
        emit Canceled(address(this), block.timestamp);
        emit ReleasedFunds(address(this));
    }

    /// @dev Complete logic is used in state and timer
    function _completeInternal() internal {
        currentState = State.Completed;
        finalizedDate = block.timestamp;

        _releaseEscrow();

        // TODO: Transfer the 1155?

        emit Completed(address(this), block.timestamp);
        emit ReleasedFunds(address(this));

        // Pay the protocol fee
        if (feeCollected > 0) {
            address t = IConfig(config()).getTreasury();
            ITreasury(t).deposit{value: feeCollected}();
        }
    }

    /// @dev Move escrow between accounts
    function _transfer(address _from, address _to, uint256 _amount) internal {
        require(balanceOf[_from] >= _amount, "Exchange: Insufficient funds");
        balanceOf[_from] -= _amount;
        balanceOf[_to] += _amount;
    }

    /// @dev Logic responsible for releasing escrow for withdraw.
    /// Releasing funds is dependent on the state of the contract.
    ///
    /// This is the place in the code where this is calculated. It only
    /// changes state - no external interaction
    function _releaseEscrow() internal {
        if (currentState == State.Expired) {
            // The buyer did not commit to the deal
            // within the required time. Allow parties to
            // withdraw whatever they escrowed.
            isAvailableToWithdraw = true;
        } else if (currentState == State.Canceled) {
            // Buyer canceled or the redeemBy timer expired
            // seller gets: buyerPenalty + their deposit
            // buyer gets: price
            _transfer(buyer, seller, buyerPenalty);
            isAvailableToWithdraw = true;
        } else if (currentState == State.Revoked) {
            // Seller revoked the deal
            // seller gets: 0
            // buyer gets : sellerDeposit + whatever they escrowed
            if (sellerDeposit > 0) {
                _transfer(seller, buyer, sellerDeposit);
            }
            isAvailableToWithdraw = true;
        } else if (currentState == State.Completed) {
            // Buyer completed or the disputeBy timer expired
            // seller gets: price + their deposits - protocol fee
            // buyer gets : buyerDeposit

            // Calculate protocol free
            uint256 fee = IConfig(config()).calculateProtocolFee(price);

            // transfer 'price' to seller.
            // This leaves an additional buyerPenalty deposit
            // available for the buyer to withdraw
            _transfer(buyer, seller, price);

            // Deduct protocol fee from seller
            balanceOf[seller] -= fee;
            feeCollected = fee;
            isAvailableToWithdraw = true;
        }
    }
}
