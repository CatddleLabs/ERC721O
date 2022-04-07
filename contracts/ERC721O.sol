// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/ILayerZeroEndpoint.sol";
import "./interfaces/ILayerZeroUserApplicationConfig.sol";
import "./interfaces/IERC721OReceiver.sol";

import "./IERC721O.sol";

/**
 * @dev Implementation of ERC721-O (Omnichain Non-Fungible Token standard), including
 * the `safeSetRemote` mechanism to avoid potential fund loss, but not including the NonBlocking extension,
 * which is available separately as {ERC721ONonBlocking}.
 */
contract ERC721O is
    ERC721,
    Ownable,
    Pausable,
    IERC721OReceiver,
    ILayerZeroUserApplicationConfig,
    IERC721O
{
    /**
     * @dev Emitted when moving token to `chainId` chain is paused
     */
    event Paused(uint16 chainId);

    /**
     * @dev Emitted when moving token to `chainId` on `chainId` chain is unpaused
     */
    event Unpaused(uint16 chainId);

    /**
     * @dev Emitted when trusted remote contract of `remoteAddress` set on `chainId` chain
     */
    event RemoteSet(uint16 chainId, bytes remoteAddress);

    // LayerZero endpoint used to send message cross chian
    ILayerZeroEndpoint internal _endpoint;

    // Mapping from chainId to trusted remote contract address
    mapping(uint16 => bytes) internal _remotes;

    // Mapping from chainId to whether move() function is paused
    mapping(uint16 => bool) internal _pauses;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection,
     * and setting address of LayerZeroEndpoint on current chain
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address layerZeroEndpoint_
    ) ERC721(name_, symbol_) {
        _endpoint = ILayerZeroEndpoint(layerZeroEndpoint_);
    }

    /**
     * @dev See {IERC721_O-endpoint}.
     */
    function endpoint() public view virtual override returns (address) {
        return address(_endpoint);
    }

    /**
     * @dev See {IERC721_O-remotes}.
     */
    function remotes(uint16 chainId)
        public
        view
        virtual
        override
        returns (bytes memory)
    {
        return _remotes[chainId];
    }

    /**
     * @dev Returns whether moving token to `chainId` chain is paused
     */
    function pauses(uint16 chainId) public view virtual returns (bool) {
        return _pauses[chainId];
    }

    /**
     * @dev Local action before move `tokenId` token to `dstChainId` chain
     */
    function _beforeMoveOut(uint16 dstChainId, uint256 tokenId)
        internal
        virtual
    {
        // burn if move to other chain
        _burn(tokenId);
    }

    /**
     * @dev Local action after `tokenId` token from  `srcChainId` chain send to `to`
     */
    function _afterMoveIn(
        uint16 srcChainId,
        address to,
        uint256 tokenId
    ) internal virtual {
        // mint when receive from other chain
        _safeMint(to, tokenId);
    }

    /**
     * @dev See {IERC721_O-move}.
     */
    function move(
        uint16 dstChainId,
        bytes calldata to,
        uint256 tokenId,
        address zroPaymentAddress,
        bytes calldata adapterParams
    ) external payable virtual override {
        require(
            !_pauses[dstChainId],
            "ERC721-O: cannot move token to a paused chain"
        );
        require(
            msg.sender == ownerOf(tokenId),
            "ERC721-O: move caller is not owner"
        );
        // only send message to trust remote contract`
        require(
            _remotes[dstChainId].length > 0,
            "ERC721-O: no remote contract on destination chain"
        );

        _beforeMoveOut(dstChainId, tokenId);

        // abi.encode() the payload
        bytes memory payload = abi.encode(to, tokenId);

        // send message via LayerZero
        _endpoint.send{value: msg.value}(
            dstChainId,
            _remotes[dstChainId],
            payload,
            payable(msg.sender),
            zroPaymentAddress,
            adapterParams
        );

        // track the LayerZero nonce
        uint64 nonce = _endpoint.getOutboundNonce(dstChainId, address(this));

        emit MoveOut(dstChainId, msg.sender, to, tokenId, nonce);
    }

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
            "ERC721-O: invalid source contract"
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

    /*
     * @dev Estimate the value of native gas token (eg. ether) required for cross chain move
     *
     * @param dstChainId the destination chain identifier (use the chainId defined in LayerZero rather than general EVM chainId)
     * @param to the address on destination chain (in bytes). address length/format may vary by chains
     * @param tokenId uint256 ID of the token to be moved
     * @param useZro whether use ZRO token for payment
     * @param adapterParams parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination
     * @returns Tuple(uint256, uint256) 0th index is for the fee in natvie gas token, while 1th index is for the fee in ZRO token
     */
    function estimateMoveFee(
        uint16 dstChainId,
        bytes calldata to,
        uint256 tokenId,
        bool useZro,
        bytes calldata adapterParams
    ) external view virtual returns (uint256 nativeFee, uint256 zroFee) {
        bytes memory payload = abi.encode(to, tokenId);
        return
            _endpoint.estimateFees(
                dstChainId,
                address(this),
                payload,
                useZro,
                adapterParams
            );
    }

    /**
     * @dev Set the trusted remote contract of `remoteAddress` on `chainId` chain
     * Auto invoke `pauseMove()` when set remote contract address to avoid avoid possible fund loss.
     * Invoke `unpauseMove()` method when ensure remote contract has invoked `setRemote()` for this contract
     *
     * Emits a {RemoteSet} event.
     */
    function safeSetRemote(uint16 chainId, bytes calldata remoteAddress)
        external
        virtual
        onlyOwner
    {
        // ensure `chainId` chain is in pause state
        if (_pauses[chainId] == false) {
            _pauses[chainId] = true;
        }
        _remotes[chainId] = remoteAddress;

        emit RemoteSet(chainId, remoteAddress);
    }

    /**
     * @dev Set the trusted remote contract of `remoteAddress` on `chainId` chain
     * @notice When remote contract has not invoked `setRemote()` for this contract,
     * invoke `pauseMove(chainId)` method before `setRemote()` to avoid avoid possible fund loss
     *
     * Requirements:
     *
     * - The remote contract must be ready to receive command
     *
     * Emits a {RemoteSet} event.
     */
    function setRemote(uint16 chainId, bytes calldata remoteAddress)
        external
        virtual
        onlyOwner
    {
        _remotes[chainId] = remoteAddress;
        emit RemoteSet(chainId, remoteAddress);
    }

    /**
     * @dev Disallow moving token to `chainId` chain
     *
     * Requirements:
     *
     * - The state is unpaused
     */
    function pauseMove(uint16 chainId) public virtual onlyOwner {
        require(_pauses[chainId] == false, "ERC721-O: already paused");
        _pauses[chainId] = true;
    }

    /**
     * @dev Permit moving token to `chainId` chain
     * @notice Only unpause when remote contract on `chainId` has invoked `setRemote()` for current contract, or fund may LOST permanently
     *
     * Requirements:
     *
     * - The state is paused
     */
    function unpauseMove(uint16 chainId) public virtual onlyOwner {
        require(_pauses[chainId] == true, "ERC721-O: unpaused");
        _pauses[chainId] = false;
    }

    /**
     * @dev See {ILayerZeroUserApplicationConfig-setConfig}.
     */
    function setConfig(
        uint16 version,
        uint16 chainId,
        uint256 configType,
        bytes calldata config
    ) external virtual override onlyOwner {
        _endpoint.setConfig(version, chainId, configType, config);
    }

    /**
     * @dev See {ILayerZeroUserApplicationConfig-setSendVersion}.
     */
    function setSendVersion(uint16 version)
        external
        virtual
        override
        onlyOwner
    {
        _endpoint.setSendVersion(version);
    }

    /**
     * @dev See {ILayerZeroUserApplicationConfig-setReceiveVersion}.
     */
    function setReceiveVersion(uint16 version)
        external
        virtual
        override
        onlyOwner
    {
        _endpoint.setReceiveVersion(version);
    }

    /**
     * @dev See {ILayerZeroUserApplicationConfig-forceResumeReceive}.
     */
    function forceResumeReceive(
        uint16 srcChainId,
        bytes calldata srcContractAddress
    ) external virtual override onlyOwner {
        _endpoint.forceResumeReceive(srcChainId, srcContractAddress);
    }
}
