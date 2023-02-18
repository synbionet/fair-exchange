// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetConstants.sol";
import "./interfaces/IBionetVoucher.sol";

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC721/extensions/ERC721Burnable.sol";

/**
 * Issues/Burns Vouchers (erc721) for buyers. Only callable
 * from exchange.
 *
 * TODO: Should the voucher be non-transferable once minted to a buyer?
 */
contract BionetVoucher is ERC721, ERC721Burnable, IBionetVoucher {
    address exchangeAddress;

    modifier onlyExchange() {
        require(msg.sender == exchangeAddress, UNAUTHORIZED_ACCESS);
        _;
    }

    /**
     * @dev Set the contract addresses.
     *
     * NOTE: Doesn't need routerAddress
     * TODO: Do we need router address?
     */
    constructor() ERC721("BionetVoucher", "BNTV") {}

    /**
     * @dev Called after default contructor to set needed addresses
     */
    function initialize(address _exchange) external {
        exchangeAddress = _exchange;
    }

    /**
     * @dev See {IBionetVoucher}
     */
    function issueVoucher(address _to, uint256 _exchangeId)
        public
        onlyExchange
    {
        _mint(_to, _exchangeId);
    }

    /**
     * @dev See {IBionetVoucher}
     */
    function burnVoucher(uint256 _exchangeId) public onlyExchange {
        _burn(_exchangeId);
    }
}
