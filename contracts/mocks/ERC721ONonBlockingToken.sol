// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../extensions/ERC721ONonBlocking.sol";

/**
 * @dev For test only
 */
contract ERC721ONonBlockingToken is ERC721ONonBlocking {
    uint256 nextTokenId = 0;

    constructor(address layerZeroEndpoint_)
        ERC721O("Catddle", "CAT", layerZeroEndpoint_)
    {}

    function mint(uint256 count) external {
        for (uint256 i = 0; i < count; ++i) {
            _safeMint(msg.sender, nextTokenId++);
        }
    }
}
