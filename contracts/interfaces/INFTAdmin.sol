// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

// import "../constants.sol";

import "../libraries/NFTStructs.sol";

import "./IBaked.sol";
import "./INFTFactory.sol";
import "./IBotPool.sol";

uint constant lenFeeReductions = 11;

interface INFTAdmin is IBaked {
    
    // ### VIEW FUNCTIONS ###
    function version() external view returns (string memory);

    function NFTFactory() external view returns (INFTFactory NFTFactory);

    function nftLevel0(uint index) external view returns (address nftLevel0);       // not intended to be called
    function nftLevel1(uint index) external view returns (address nftLevel1);       // ...
    function nftLevel2(uint index) external view returns (address nftLevel2);       // ...
    function nftLevel3(uint index) external view returns (address nftLevel3);       // ...
    function nftLevel4(uint index) external view returns (address nftLevel4);       // ...
    function allNFTs(uint index, uint _index) external view returns (address nft);  // ...
    function isNFTContract(address nftAddress) external view returns (bool isNFTContract);
    function maxNFTLevel() external view returns (uint8 maxNFTLevel);

    function newUserBaseNFTArray(uint index) external view returns (uint newUserBaseNFTArray);

    function nftNumUsers() external view returns (uint nftNumUsers);
    function userIDs(address userAddress) external view returns (uint userID);
    function userAddress(uint userID) external view returns (address userAddress);
    function isRegistered(uint userID) external view returns (bool isRegistered);
    function userNFTLevels(uint index, uint _index) external view returns (uint userNFTLevel);
    function highestOwnedLevel(uint userID) external view returns (uint8 highestOwnedLevel);

    function BotPool() external view returns (IBotPool BotPool);

    function getTreasuryWallet() external view returns (address treasuryWalletFromBotPool);

    function isTeamWallet(address verifyMe) external view returns (bool isTeamWallet);




    // ### GETTER FUNCTIONS ###
    function getAllNFTs() external view returns (address[][] memory allNFTs);

    function getLevelOf(address nft) external view returns (uint8 level);

    function highestLevelOf(address account) external view returns (uint8 highestLevel);

	function levelBalancesOf(address account) external view returns (uint[lenFeeReductions] memory levelBalances);

	function nftsOf(address account) external view returns (NFTStructs.accountNFTs[] memory userOwnedNFTs);




    // ### USER FUNCTIONS ###
    function addUser(address account) external;

    function updateUserLevel(address _from, address _to) external;

    function nftTransferNotification(address _from, address _to) external; // _nftContractAuth




    // ### NFT FUNCTIONS ###
    function addNFTLevel() external;

    function setNFTFactory(address _nftFactory) external;

    function addNewNFT(address _newNft) external; // _adminAuth

    function mintNewNFT(string[] memory contractInfo, uint8 level, NFTStructs.NFT[] memory NFTs) external returns (address newNFT);

}