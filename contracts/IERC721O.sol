// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev Interface of the ERC721-O (Omnichain Non-Fungible Token standard)
 */
interface IERC721O is IERC721 {
    /**
     * @dev Emitted when `tokenId` token is sent from `from` on current chain to `to` on `dstChainId` chain.
     */
    event MoveOut(
        uint16 dstChainId,
        address indexed from,
        bytes indexed to,
        uint256 indexed tokenId,
        uint64 nouce
    );

    /**
     * @dev Emitted when `tokenId` token is sent from `from` on `srcChainId` chain to `to` on current chain.
     */
    event MoveIn(
        uint16 srcChainId,
        bytes indexed from,
        address indexed to,
        uint256 indexed tokenId,
        uint64 nouce
    );

    /**
     * @dev Returns the address of cross chain endpoint
     */
    function endpoint() external view returns (address);

    /**
     * @dev Returns the remote trusted contract address on chain `chainId`.
     */
    function remotes(uint16 chainId) external view returns (bytes memory);

    /**
     * @dev Move `tokenId` token from current chain to `to` address on the `dstChainId` chain.

     * WARNING:  This action will BURN/Lock the token on the current chain,
     * and then message to the contract on destination chain to MINT/UNLOCK one. 
     * If the contract on destination chain is not ready to receive the command, fund will LOST permanently.
     *
     * Requirements:
     *
     * -  Receiver contract on the `dstChainId` chain must be ready to receive the move command on the destination chain.
     * - `dstChainId` and receiver contract address must be setted in `remotes`.
     * -  msg.value must equal or bigger than the total gas fee for cross chain operation.
     * - `tokenId` must exist.
     * - The caller must own the token.
     *
     * @param dstChainId the destination chain identifier (use the chainId defined in endpoint rather than general EVM chainId)
     * @param to the address on destination chain (in bytes). address length/format may vary by chains
     * @param tokenId uint256 ID of the token to be moved
     * @param tokenPaymentAddress the address of payment token (eg. ZRO) holder who would pay for the transaction
     * (use address(0x0) to pay by native gas token (eg. ether) only)
     * @param adapterParams parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination
     *
     * Emits a {MoveOut} event.
     */
    function move(
        uint16 dstChainId,
        bytes calldata to,
        uint256 tokenId,
        address tokenPaymentAddress,
        bytes calldata adapterParams
    ) external payable;
}
