// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC721O.sol";

/**
 * @dev For test only
 */
contract ERC721OToken is ERC721O {
    uint256 nextTokenId = 0;

    constructor(address layerZeroEndpoint_)
        ERC721O("Catddle", "CAT", layerZeroEndpoint_)
    {}
}
