// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

// import "./constants.sol";

import "./libraries/Caffeinated.sol";

import "./interfaces/INFTAdmin.sol";
import "./interfaces/INFTBase.sol";
import "./interfaces/IERC20.sol";

contract RemainingPotheads { // is IBotTrader {
	
	// @dev
	// @notice
	// The date when this contract was last edited in yyyy-mm-dd
    // format with an appended project-wide phase label.
    string public constant version = "2023-03-25 | Beta";
	
	address public constant adminWallet_ = 0xC25f0B6BdBB2b3c9e8ef140585c664727B3B9D60;
	address public adminWallet2_;
	address public adminWallet3_ = 0x79e22e0F1d44F55CEBF1694F47A6fd0D798De018;
	address public treasuryWallet_;
	INFTAdmin public NFTAdmin_;

	uint[5] public avaxPrices = [
		0,
		20,
		40,
		200,
		800
	];

	uint[][5] public tokenIds; // ! IS THIS CORRECT ?????
	uint[5] public nftBalances;
	INFTBase[5] public potheads;

	constructor() {
		adminWallet2_ = msg.sender;
		treasuryWallet_ = msg.sender;
		uint _avaxDenominator = 10 ** 18;

		for (uint8 i; i < 5; ++i) {
			avaxPrices[i] *= _avaxDenominator;
		}
	}

	modifier _adminOnly {
		require(
			msg.sender == adminWallet_
			|| msg.sender == adminWallet2_
			|| msg.sender == adminWallet3_,
			"POTHEADS | AUTH: Only adminWallet permitted."
		);
		_;
	}

	function setAdminWallet2(address _adminWallet2) external _adminOnly {
		adminWallet2_ = _adminWallet2;
	}

	function setAdminWallet3(address _adminWallet3) external _adminOnly {
		adminWallet3_ = _adminWallet3;
	}

	function setTreasuryWallet(address _treasuryWallet) external _adminOnly {
		require(
			_treasuryWallet != address(0),
			"POTHEADS | SET TREASURYWALLET: Must not be the null address."
		);
		treasuryWallet_ = _treasuryWallet;
	}

	function setNftAdmin(address _nftAdmin) external _adminOnly {
		INFTAdmin __nftAdmin = INFTAdmin(_nftAdmin);
		require(
			_nftAdmin != address(0)
			&& Caffeinated.isContract(_nftAdmin),
			"POTHEADS | SET NFTADMIN: Must be a real contract."
		);

		require(
			keccak256(abi.encode(__nftAdmin.getAllNFTs()))
			== keccak256(abi.encode(NFTAdmin_.getAllNFTs())),
			"POTHEADS | SET NFTADMIN: Must have identical NFTs."
		);
		
		NFTAdmin_ = __nftAdmin;
	}

	function setPotheads(address[4] calldata _potheads) external _adminOnly {
		for (uint8 i; i < 4; ++i) {
			INFTBase __pothead = INFTBase(_potheads[i]);
			require(
				address(__pothead.NFTAdmin()) == address(NFTAdmin_),
				string.concat(
					"POTHEADS | SET POTHEADS: Index [",
					Caffeinated.uintToString(i),
					"] of given potheads has a different NFTAdmin."
				)
			);
			require(
				__pothead.level() == i + 1,
				string.concat(
					"POTHEADS | SET POTHEADS: Index [",
					Caffeinated.uintToString(i),
					"] of given potheads does not have a matching Level."
				)
			);
			potheads[i + 1] = __pothead;
			nftBalances[i + 1] = __pothead.balanceOf(address(this));
			tokenIds[i + 1] = __pothead._getNftsOf(address(this), bytes1(0x01)).tokenIds;
		}
	}

	function refreshBalances() external {
		for (uint8 i = 1; i < 5; ++i) {
			nftBalances[i] = potheads[i].balanceOf(address(this));
			tokenIds[i] = potheads[i]._getNftsOf(address(this), bytes1(0x01)).tokenIds;
		}
	}
	
	function obtainNft(uint8 _level) payable external {
		require(
			_level > 0
			&& _level < 5,
			"POTHEADS | OBTAIN: Invalid Level requested."
		);
		require(
			msg.value >= avaxPrices[_level],
			"POTHEADS | OBTAIN: Insufficient AVAX transferred."
		);
		if (msg.value > avaxPrices[_level]) {
			(
				bool __success,
				// bytes
			) = payable(msg.sender).call{value: (msg.value - avaxPrices[_level])}("");
			require(__success, "POTHEADS | OBTAIN: Refund failed.");
		}
		require(
			nftBalances[_level] == tokenIds[_level].length,
			"POTHEADS | OBTAIN: Internal balances out-of-sync."
		);

		_transferPothead(msg.sender, _level);
		// Send all AVAX to the treasury wallet
		(
			bool _success,
			// bytes
		) = payable(treasuryWallet_).call{value: address(this).balance}("");
		require (_success, "POTHEADS | OBTAIN: Payment failed.");
	}

	IERC20 public constant WAVAX = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

	function obtainNftWithWAVAX(uint8 _level) payable external {
		require(
			_level > 0
			&& _level < 5,
			"POTHEADS | OBTAIN W WAVAX: Invalid Level requested."
		);
		require(
			WAVAX.allowance(msg.sender, address(this)) >= avaxPrices[_level],
			"POTHEADS | OBTAIN W WAVAX: Insufficient WAVAX allowance. Approve() more."
		);
		require(
			nftBalances[_level] == tokenIds[_level].length,
			"POTHEADS | OBTAIN W WAVAX: Internal balances out-of-sync."
		);

		WAVAX.transferFrom(msg.sender, treasuryWallet_, avaxPrices[_level]);
		_transferPothead(msg.sender, _level);
	}

	function sendProceedsToTreasury(address token) external {
		// Pass in `address(0)` to send AVAX to the Treasury.
		if (token == address(0)) {
			(
				bool _success,
				// bytes
			) = payable(treasuryWallet_).call{value: address(this).balance}("");
			require(_success, "POTHEADS | SEND PROCEEDS: Sending failed.");
			return;
		}

		// Otherwise send any balance of the given token to the Treasury.
		IERC20 _token = IERC20(token);
		_token.transfer(treasuryWallet_, _token.balanceOf(address(this)));
	}

	function _transferPothead(address _to, uint8 _level) private {
		potheads[_level].safeTransferFrom(
			address(this),
			_to,
			tokenIds[_level][tokenIds[_level].length - 1]
		);
		--nftBalances[_level];
		tokenIds[_level].pop();
	}

	function returnAllNFTsToAdmin() external _adminOnly {
		for (uint8 i = 1; i < 5; ++i) {
			_transferPothead(adminWallet_, i);
		}
	}




}