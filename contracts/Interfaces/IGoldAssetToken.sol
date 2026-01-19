// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGoldAssetToken {
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function isAssetLocked(uint256 tokenId) external view returns (bool);
}
