// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

library NFTStructs {

    struct NFT {
        uint tokenId;
        string name;
        string uri;
        string description;
        address owner;
        address approved; // ERC-721 requires only ONE `approved` address
    }

    struct accountNFTs {
		address nft;
		uint balance;
        uint[] tokenIds;
        NFT[] nfts;
	} 

}