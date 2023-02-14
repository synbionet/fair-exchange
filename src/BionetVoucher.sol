// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "./BionetConstants.sol";
import "./interfaces/IBionetVoucher.sol";

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC721/extensions/ERC721Burnable.sol";

contract BionetVoucher is ERC721, ERC721Burnable, IBionetVoucher {
    address routerAddress;
    address exchangeAddress;

    modifier onlyExchange() {
        require(msg.sender == exchangeAddress, UNAUTHORIZED_ACCESS);
        _;
    }

    constructor(address _router, address _exchange)
        ERC721("BionetVoucher", "BNTV")
    {
        routerAddress = _router;
        exchangeAddress = _exchange;
    }

    function issueVoucher(address _to, uint256 _exchangeId)
        public
        onlyExchange
    {
        // Record in store???
        _mint(_to, _exchangeId);
    }

    function burnVoucher(uint256 _exchangeId) public onlyExchange {
        _burn(_exchangeId);
    }
}
