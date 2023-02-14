// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "openzeppelin/token/ERC721/IERC721.sol";

// Handle redeemable vouchers for exchanges. ERC721
// each voucher should link to asset 1155
interface IBionetVoucher is IERC721 {
    // only exchange can call below?
    function issueVoucher(address _to, uint256 _exchangeId) external;

    function burnVoucher(uint256 _exchangeId) external;
}
