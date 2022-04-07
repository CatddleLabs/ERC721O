// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721ONonBlocking.sol";

/**
 * @dev Implementation of ERC721-O (Omnichain Non-Fungible Token standard) NoBurning Extension,
 * including the NonBlocking extension. Avoid token burning to keep acquired data.
 *
 * Ensure tokens with same tokenId will not be minted on different chains by user defined mint function
 */
abstract contract ERC721ONoBurning is ERC721ONonBlocking {
    /**
     * @dev See {IERC721_O-_beforeMoveOut}.
     */
    function _beforeMoveOut(uint16, uint256 tokenId) internal virtual override {
        // transfer in this contract to lock
        _transfer(msg.sender, address(this), tokenId);
    }

    /**
     * @dev See {IERC721_O-_afterMoveIn}.
     */
    function _afterMoveIn(
        uint16,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (_exists(tokenId)) {
            // if the token came current chain before, transfer it to `to`
            if (ownerOf(tokenId) == address(this)) {
                _transfer(address(this), to, tokenId);
            } else {
                // token duplicate, cannot transfer token not under lock of this contract
            }
        } else {
            // mint if the token never come to current chain
            _safeMint(to, tokenId);
        }
    }
}
