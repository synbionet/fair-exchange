// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

interface IBionetFunds {
    event EscrowDeposit(address indexed account, uint256 amount);
    event EscrowWithdraw(address indexed account, uint256 amount);
    event EscrowEncumbered(
        address indexed user,
        uint256 indexed offerid,
        uint256 amount
    );
    event FundsReleased(
        uint256 indexed _exchangeId,
        address indexed receiver,
        uint256 amount
    );

    event ProtocolFeeCollected(uint256 indexed _exchangeId, uint256 amount);

    function withdraw(address _account, uint256 _amount) external;

    function encumberFunds(
        address _buyer,
        uint256 _price,
        uint256 _offerId
    ) external payable;

    function releaseFunds(
        uint256 _exchangeId,
        address _seller,
        address _buyer,
        uint256 _price,
        BionetTypes.ExchangeState _state
    ) external;

    function getEscrowBalance(address _account) external view returns (uint256);

    function getProtocolBalance() external view returns (uint256);
}
