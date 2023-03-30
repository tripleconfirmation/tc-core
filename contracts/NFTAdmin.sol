// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

/*
Master NFT Contract:
- Can mint NFTs
- Keeps track of highest NFT level for each user
- Accepts requests from other NFTs regarding who owns what NFT

Each NFT Contract:
- Sends requests to Master NFT regarding who own what NFT
*/

// import "./constants.sol";

import "./Baked.sol";

import "./libraries/NFTStructs.sol";
import "./libraries/Caffeinated.sol";

import "./interfaces/INFTBase.sol";
import "./interfaces/INFTFactory.sol";
import "./interfaces/IBotPool.sol";

contract NFTAdmin {

	string public constant version = "2023-03-25 | Alpha v2";

	INFTFactory public NFTFactory;
	
	address[][lenFeeReductions] public nfts; // expected that Level 0 is empty

	function getAllNFTs(
		// no arguments
	) public view returns (
		address[][lenFeeReductions] memory
	) {
		return nfts;
	}

	mapping(address => bool) public isNFTContract;
	uint8 public highestLevelNft; // ! Need to set !!

	// uint[] public newUserBaseNFTArray = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];

	uint public nftNumUsers;
	mapping(address => uint) public userNum;
	mapping(uint => address) public user;
	mapping(address => uint[lenFeeReductions]) public levelBalances;
    mapping(address => uint8) public highestLevelOwned;
	mapping(address => uint) public accountTotalNfts;

	IBotPool public BotPool;

	address public adminWallet;

	constructor() {
		adminWallet = msg.sender;
		_addUser(adminWallet);
	}




	// ### AUTHORISATION FUNCTIONS ###
	modifier _nftContractAuth() {
		require(
			isNFTContract[msg.sender],
			"NFT ADMIN | AUTH ERROR: Sender is not a valid NFT contract."
		);
		_;
	}

    modifier _adminAuth() {
        require(
			msg.sender == adminWallet,
			"NFT ADMIN | AUTH ERROR: Sender is not the Admin Wallet."
		);
        _;
    }




	// ### GETTER FUNCTIONS ###
	function getLevelOf(address nft) external view returns (uint8) {
		return INFTBase(nft).level();
	}

	function highestLevelOf(address account) public view returns (uint8) {
		return highestLevelOwned[account];
	}

	function levelBalancesOf(address account) public view returns (uint[lenFeeReductions] memory) {
		return levelBalances[account];
	}

    function nftsOf(
		address account
	) public view returns (
		NFTStructs.accountNFTs[] memory _userOwned
	) {
		uint _len = accountTotalNfts[account];
        _userOwned = new NFTStructs.accountNFTs[](_len);

		uint _count;

		// Get into the interior array (first set of [] left).
		for (uint i = 0; i < nfts.length; ++i) {

			// Get into the exterior array (second set of [] right).
            for (uint x = 0; x < nfts[i].length; x++) {

				// Grab the each individual NFT address and
				// cast it to `INFTBase`.
                INFTBase _nft = INFTBase(nfts[i][x]);

				// Check the `balanceOf(account)`
                uint _userNFTbalance = _nft.balanceOf(account);

				// and if greater than 0, get a list of all NFTs
				if (_userNFTbalance > 0) {
					// the `account` owns in that NFT contract.
					_userOwned[_count++] = _nft.getNftsOf(account);
				}

				// If the `_count` of NFTs matches the user's
				// recorded `accountTotalNfts` quantity
				// then return the saved array.
				if (_count >= _len) {
					return _userOwned;
				}
			}
		}
	
		return _userOwned;
    }



	// ### SETTER FUNCTIONS ###
	function setBotPool(address botPool) external _adminAuth {
		require(address(BotPool) == address(0), "BotPool has already been set.");
		BotPool = IBotPool(botPool);
	}

	function getTreasuryWallet() public view returns (address) {
		return BotPool.botController().treasuryWallet(); // addresses(treasuryWallet);
	}

	function isTeamWallet(address verifyMe) external view returns (bool) {
		return BotPool.adminLevel(verifyMe) || verifyMe == getTreasuryWallet();
	}




	// ### USER FUNCTIONS ###
	function _addUser(address account) private {
		if (userNum[account] > 0) {
            return;
        }

        // user 0 must be empty
        ++nftNumUsers;
        userNum[account] = nftNumUsers; // purely for looping through each user
        user[nftNumUsers] = account;
	}

	function addUser(address account) external _nftContractAuth {
		_addUser(account);
	}

	function nftTransferNotification(address _from, address _to) external _nftContractAuth {
		_addUser(_to);
		// Before doing anything, notify BotPool
		// since the levels updating could affect
		// farm rewards accrued to date.
		BotPool.nftTransferNotification(_from);
		BotPool.nftTransferNotification(_to);

		--accountTotalNfts[_from];
		++accountTotalNfts[_to];

		INFTBase NFTcontract = INFTBase(msg.sender);
		uint8 nftLevel = NFTcontract.level();

		// ! NEED TO REWRITE
		// uint userIDFrom = userIDs[_from];
		// uint userIDTo = userIDs[_to];

		// while (userNFTLevels[userIDFrom].length < allNFTs.length) {
		// 	userNFTLevels[userIDFrom].push(0);
		// }

		// while (userNFTLevels[userIDTo].length < allNFTs.length) {
		// 	userNFTLevels[userIDTo].push(0);
		// }

		// --userNFTLevels[userIDFrom][nftLevel];
		// ++userNFTLevels[userIDTo][nftLevel];

		// delete highestOwnedLevel[userIDFrom];
		// delete highestOwnedLevel[userIDTo];

		// for (uint8 _level = 1; _level <= maxNFTLevel; _level++) {
		// 	if (userNFTLevels[userIDFrom][_level] > 0) {
		// 		highestOwnedLevel[userIDFrom] = _level;
		// 	}

		// 	if (userNFTLevels[userIDTo][_level] > 0) {
		// 		highestOwnedLevel[userIDTo] = _level;
		// 	}
		// }
	}




	// ### NFT FUNCTIONS ###

	// TE: I was wrong to have this functionality. Hardcode is the way to go.
	// // function addNFTLevel() external _adminAuth {
	// // 	address[] memory newLevel;
	// // 	allNFTs.push(newLevel);
	// // 	maxNFTLevel = uint8(allNFTs.length - 1);
	// // 	newUserBaseNFTArray.push(0);
	// // }

	function setNFTFactory(address newNFTFactory) external _adminAuth {
		NFTFactory = INFTFactory(newNFTFactory);
	}

	function addNewNFT(address _newNft) external _adminAuth {
		INFTBase __newNft = INFTBase(_newNft);
		try __newNft.level() returns (uint8 __level) {
			require(
				__level > 0 && __level < lenFeeReductions,
				"NFTADMIN: Invalid Level."
			);
			try __newNft.getNftsOf(address(this)) returns (NFTStructs.accountNFTs memory) {

				nfts[__level].push(_newNft);
				levelBalances[adminWallet][__level] += __newNft.totalSupply();
				accountTotalNfts[adminWallet] += __newNft.totalSupply();

				// Further verification of the NFT.
				try __newNft.totalSupply() returns (uint totalCreated) {
					require(
						totalCreated > 0,
						"NFTADMIN: Invalid Triple Confirmation NFT. None created."
					);
					try __newNft.ownerOf(0) returns (address owner) {
						require(
							owner != address(0),
							"NFTADMIN: Invalid Triple Confirmation NFT. Some owned by null address."
						);
					}
					catch {
						revert("NFTADMIN: Invalid Triple Confirmation NFT. No owner of tokenID[0].");
					}
				}
				catch {
					revert("NFTADMIN: Invalid Triple Confirmation NFT. None minted.");
				}
			}
			catch {
				revert("NFTADMIN: Invalid Triple Confirmation NFT. No token IDs.");
			}
		}
		catch {
			revert("NFTADMIN: Invalid Triple Confirmation NFT. No Level.");
		}
		
		isNFTContract[_newNft] = true;
	}

	function transferAllTo(
		NFTStructs.accountNFTs[] calldata _ownedNfts,
		address _to
	) external {
		uint _loopMinGas = 2000000; // @Beta>> BotPool.uints(loopMinGas);
		require(
			gasleft() >= _loopMinGas,
			string.concat(
				"NFTADMIN | MIN GAS: Submit with ",
				Caffeinated.uintToString(_loopMinGas),
				" gas."
			)
		);

		uint _minGas = 200000; // @Beta>> BotPool.uints(loopBreakAtGasleftThreshold);
		for (uint i; i < _ownedNfts.length; ++i) {
			for (uint x; x < _ownedNfts[i].tokenIds.length; ++x) {
				if (gasleft() < _minGas) {
					return;
				}
				INFTBase(_ownedNfts[i].nft).transferFrom(msg.sender, _to, _ownedNfts[i].tokenIds[x]);
			}
		}
	}

	function mintNewNFT(
		string[] calldata contractInfo,
		uint8 level,
		NFTStructs.NFT[] calldata NFTs
	) external _adminAuth {
		address _newNFT = NFTFactory.mintNewNFT(contractInfo, level, NFTs);
        nfts[level].push(_newNFT);
		isNFTContract[_newNFT] = true;
		levelBalances[adminWallet][level] += INFTBase(_newNFT).totalSupply();
		accountTotalNfts[adminWallet] += INFTBase(_newNFT).totalSupply();
	}

}