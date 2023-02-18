// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetConstants.sol";
import {IBionetVoucher} from "./interfaces/IBionetVoucher.sol";

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "openzeppelin/token/ERC721/extensions/ERC721Burnable.sol";

/// @dev Issues/Burns Vouchers (erc721) for buyers. Only callable from exchange.
/// TODO: Should the voucher be non-transferable once minted to a buyer?
///
contract BionetVoucher is ERC721, ERC721Burnable, IBionetVoucher {
    address exchangeAddress;

    // msg.sender must be the exchange address
    modifier onlyExchange() {
        require(msg.sender == exchangeAddress, UNAUTHORIZED_ACCESS);
        _;
    }

    /// @dev Set the contract addresses.
    constructor() ERC721("BionetVoucher", "BNTV") {}

    /// @dev Called after default constructor to set exchange address
    /// @param _exchange address
    function initialize(address _exchange) external {
        exchangeAddress = _exchange;
    }

    /// @dev Issue a voucher.  Done during the commit
    /// @param _to - the recipient
    /// @param _exchangeId of the exchange
    ///
    /// Note: exchangeId is the tokenID
    function issueVoucher(address _to, uint256 _exchangeId)
        public
        onlyExchange
    {
        _mint(_to, _exchangeId);
    }

    /// @dev Burn a voucher. Via: Cancel, Revoke, Redeem
    /// @param _exchangeId of the exchange
    function burnVoucher(uint256 _exchangeId) public onlyExchange {
        _burn(_exchangeId);
    }
}
