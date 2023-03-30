// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./NFTBase.sol";

import "./interfaces/INFTAdmin.sol";

contract NFTFactory {

    INFTAdmin public immutable NFTAdmin;

    constructor(address _NFTAdmin) {
        NFTAdmin = INFTAdmin(_NFTAdmin);
    }




    // ### AUTHORISATION FUNCTIONS ###
    modifier _NFTAdminAuth() {
        require(msg.sender == address(NFTAdmin), "NFT FACTORY | AUTH ERROR: Sender is not the NFT Admin contract.");
        _;
    }




    // ### FACTORY FUNCTIONS ###
    function mintNewNFT(string memory _name, string memory _symbol, uint8 level, NFTStructs.NFT[] memory NFTs) external _NFTAdminAuth returns (address newNFTContract) {
        NFTBase _newNFTContract = new NFTBase(address(NFTAdmin), _name, _symbol, level, NFTs);

        return address(_newNFTContract);
    }

}