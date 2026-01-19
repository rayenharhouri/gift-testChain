// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDocumentRegistry {
    function getDocumentSetDetails(
        string memory setId
    )
        external
        view
        returns (
            string memory,
            bytes32,
            string memory,
            string memory,
            string[] memory,
            uint8,
            uint256
        );
}
