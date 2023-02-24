// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC1155/ERC1155.sol";

// Mock for an IP Asset
contract IpAsset is ERC1155, Ownable {
    constructor() ERC1155("http://mocker.com") {
        _mint(msg.sender, 1, 10, "");
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        _mint(account, id, amount, data);
    }
}
