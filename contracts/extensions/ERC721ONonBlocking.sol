// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC721O.sol";

/**
 * @dev Implementation of ERC721-O (Omnichain Non-Fungible Token standard) NonBlocking Extension.
 * Using NonBlocking mechnism to ensure message from remote sending contract will not be stucked due to local error/excpetion.
 */
abstract contract ERC721ONonBlocking is ERC721O {
    /**
     * @dev Emitted when message execution failed
     */
    event MessageFailed(
        uint16 srcChainId,
        bytes indexed from,
        uint64 nonce,
        bytes payload
    );

    /**
     * @dev Failed message info
     */
    struct FailedMessages {
        uint256 payloadLength;
        bytes32 payloadHash;
    }

    /**
     * @dev `FailedMessgaes` struct located by chainId, source contract address, and nonce together
     */
    mapping(uint16 => mapping(bytes => mapping(uint256 => FailedMessages)))
        public failedMessages;

    /**
     * @dev See {IERC721OReceiver-lzReceive}.
     */
    function lzReceive(
        uint16 srcChainId,
        bytes memory from,
        uint64 nonce,
        bytes memory payload
    ) external virtual override {
        // lzReceive must only be called by the endpoint
        require(msg.sender == address(_endpoint));
        // only receive message from `_remotes`
        require(
            from.length == _remotes[srcChainId].length &&
                keccak256(from) == keccak256(_remotes[srcChainId]),
            "ERC721ONonBlocking: invalid source contract"
        );

        // catch all exceptions to avoid failed messages blocking message path
        try this.onLzReceive(srcChainId, from, nonce, payload) {
            // pass if succeed
        } catch {
            failedMessages[srcChainId][from][nonce] = FailedMessages(
                payload.length,
                keccak256(payload)
            );
            emit MessageFailed(srcChainId, from, nonce, payload);
        }
    }

    /**
     * @dev Invoked by internal transcation to handle lzReceive logic
     */
    function onLzReceive(
        uint16 srcChainId,
        bytes memory from,
        uint64 nonce,
        bytes memory payload
    ) public virtual {
        // only allow internal transaction
        require(
            msg.sender == address(this),
            "ERC721ONonBlocking: only internal transcation allowed"
        );

        // decode the payload
        (bytes memory to, uint256 tokenId) = abi.decode(
            payload,
            (bytes, uint256)
        );

        address toAddress;
        // get toAddress from bytes
        assembly {
            toAddress := mload(add(to, 20))
        }

        _afterMoveIn(srcChainId, toAddress, tokenId);

        emit MoveIn(srcChainId, from, toAddress, tokenId, nonce);
    }

    /**
     * @dev Retry local stored failed messages
     */
    function retryMessage(
        uint16 srcChainId,
        bytes memory from,
        uint64 nonce,
        bytes calldata payload
    ) external payable {
        // assert there is message to retry
        FailedMessages storage failedMsg = failedMessages[srcChainId][from][
            nonce
        ];
        require(
            failedMsg.payloadHash != bytes32(0),
            "ERC721ONonBlocking: no stored message"
        );
        require(
            payload.length == failedMsg.payloadLength &&
                keccak256(payload) == failedMsg.payloadHash,
            "ERC721ONonBlocking: invalid payload"
        );
        // clear the stored message
        failedMsg.payloadLength = 0;
        failedMsg.payloadHash = bytes32(0);
        // execute the message. revert if it fails again
        this.onLzReceive(srcChainId, from, nonce, payload);
    }

    /**
     * @dev See {ILayerZeroUserApplicationConfig-forceResumeReceive}.
     * In nonBlocking mode `forceResumeReceive()` should be useless
     */
    function forceResumeReceive(
        uint16 srcChainId,
        bytes calldata srcContractAddress
    ) external virtual override onlyOwner {}
}
