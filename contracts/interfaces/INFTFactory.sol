// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./INFTAdmin.sol";

import "../libraries/NFTStructs.sol";

interface INFTFactory {

    // ### VIEW FUNCTIONS ###
    function NFTAdmin() external view returns (INFTAdmin NFTAdmin);




    // ### FACTORY FUNCTIONS ###
    function mintNewNFT(string[] memory contractInfo, uint8 _level, NFTStructs.NFT[] memory NFTs) external returns (address newNFTContract);

}