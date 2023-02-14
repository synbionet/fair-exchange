// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "openzeppelin/token/ERC721/IERC721.sol";

/**
 * @dev Issues and Burns Vouchers. Vouchers are redeemable
 * by buyers.  Issued when a buyer commits to a purchase.
 * Can be used as proof of purchase.
 *
 * Voucher tokenIds are the exchange ID.
 * Each exchange has 1 Voucher.
 */
interface IBionetVoucher is IERC721 {
    /**
     * @dev Issue a voucher 'to' for the given exchange
     */
    function issueVoucher(address _to, uint256 _exchangeId) external;

    /**
     * @dev Burn a voucher for the specific exchange.
     */
    function burnVoucher(uint256 _exchangeId) external;
}
