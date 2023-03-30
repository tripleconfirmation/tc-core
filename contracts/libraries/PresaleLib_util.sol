// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

// import "../constants.sol";

import "./Caffeinated.sol";
import "./PresaleLib_structs.sol";

import "../interfaces/IPresale.sol";
import "../interfaces/IBotPool.sol";
import "../interfaces/IERC20T.sol";

// import "hardhat/console.sol";

library PresaleLib_util {

	// event MigrationStatus(uint completedAccounts, uint totalAccounts, uint tcTotal, uint tccTotal);
    // event MigrationDone();

	// uint8 public constant t = 5; // MUST == BotPool.t()
	
	// struct UserStruct {
    //     uint userID;
    //     address adresse;
    //     bool isRegistered;
    //     bool[t] nftRewards;
    //     uint spentUSDC;
    //     uint spentUSDCe;
    //     uint balanceTotalEver;  // total TC balance
    //     uint balanceBonus;      // total bonus TC ever received by this user via Vesting
    //     uint balanceBonusFromYourReferrals;
    //     uint balanceBonusFromUsingReferrals;
    //     uint balanceVested;     // amount of TC vested; cumulative; used for `extraBonusThreshold` 2% on 100k TC
    //     uint balance;           // current balance available to vest or to be withdrawn at CROWDFUND end
    //     uint balanceTCC;
    //     string referralCode;
    // }

	// function emptyUser() public pure returns (UserStruct memory) {
	// 	return 
	// 		UserStruct(
	// 			0,
	// 			address(0),
	// 			false,
	// 			[false, false, false, false, false],
	// 			0,
	// 			0,
	// 			0,
	// 			0,
	// 			0,
	// 			0,
	// 			0,
	// 			0,
	// 			0,
	// 			""
	// 		);
	// }

	// uint8 constant lenLoopExistingBalances = 6;
	// uint8 constant _ownerCompleted = 0;
	// uint8 constant _ownerCount = 1;
	// uint8 constant _existingTC = 2;
	// uint8 constant _existingTCC = 3;
	// uint8 constant _requiredTC = 4;
	// uint8 constant _requiredTCC = 5;

	// function loopExistingBalances(
	// 	address[] memory _existingOwners,
	// 	uint[] memory _existingTCBalances,
	// 	uint[] memory _existingTCCBalances
	// ) external returns (
	// 	uint,
	// 	uint,
	// 	uint
	// ) {
	// 	IPresale Presale = IPresale(address(this));

	// 	uint[lenLoopExistingBalances] memory _vals = [
	// 		Presale.ownerCompleted(),
	// 		Presale.ownerCount(),
	// 		0,
	// 		0,
	// 		Presale.requiredTC(),
	// 		Presale.requiredTCC()
	// 	];
    //     require(_vals[_ownerCount] > 0, "CROWDFUND | SETUP: No balances remembered.");
    //     require(_vals[_ownerCompleted] < _ownerCount, "CROWDFUND | SETUP: Already completed.");

    //     for (; _vals[_ownerCompleted] < _existingOwners.length; ++_vals[_ownerCompleted]) {
    //         if (gasleft() < 500000) {
	// 			_vals[_existingTC] = _vals[_existingTC] * 105 / 100;

	// 			return (
	// 				_vals[_ownerCompleted]							  /* ownerCompleted */,
	// 				_vals[_requiredTC] + (_vals[_existingTC] * 112 / 100) /* requiredTC */,
	// 				_vals[_requiredTCC] + _vals[_existingTCC]            /* requiredTCC */
	// 			);

    //             // Presale.setLoopBalancesVals(
	// 			// 	i                       /* ownerCompleted */,
	// 			// 	_existingTC * 112 / 100 /* requiredTC */,
	// 			// 	_existingTCC            /* requiredTCC */
	// 			// );

    //             // break;
    //         }

    //         uint _userID = Presale._addUser(_existingOwners[_vals[_ownerCompleted]]);

	// 		UserStruct memory _user = Presale.users_(_userID);
    //         _user.balance 			= _existingTCBalances[_vals[_ownerCompleted]];
    //         _user.balanceTotalEver  = _existingTCBalances[_vals[_ownerCompleted]];
    //         _user.balanceTCC 		= _existingTCCBalances[_vals[_ownerCompleted]];
	// 		Presale._setUser(_user);
    //         _vals[_existingTC] 	   += _user.balance;
    //         _vals[_existingTCC]    += _user.balanceTCC;
    //     }

    //     // +5% for referral codes
    //     _vals[_existingTC] = _vals[_existingTC] * 105 / 100;

    //     // +12% max possible global bonus TC for vesting
    //     _vals[_requiredTC] += (_vals[_existingTC] * 112 / 100);
	// 	_vals[_requiredTCC] += _vals[_existingTCC];
    //     // requiredTCC += _existingTCC;
        

    //     emit MigrationStatus(
	// 		_vals[_ownerCompleted],
	// 		_vals[_ownerCount],
	// 		_vals[_requiredTC],
	// 		_vals[_requiredTCC]
	// 	);

    //     if (_vals[_ownerCompleted] == _vals[_ownerCount]) {
    //         emit MigrationDone();
    //     }

	// 	return (_vals[_ownerCompleted], _vals[_requiredTC], _vals[_requiredTCC]);
	// }

    // uint8 public constant n = 6; // Number of Rounds

	// struct Info {
    //     // User user;
    //     uint numUsers;
    //     uint[n] TCRounds;
    //     uint[n] USDPrice;
    //     uint currentRound;
    //     uint totalTC;
    //     uint totalSpentUSD;
    //     uint totalPurchasedTC;
    //     uint totalPurchasedTCSinceLastRound;
    //     uint totalTCGivenForReferrals;
    // }

	// function getInfo(uint _numUsers) external view returns (Info memory info) {
	// 	IPresale Presale = IPresale(address(this));
	// 	return info;

    //     // info.numUsers = _numUsers;
    //     // info.TCRounds = TCRounds;
    //     // info.USDPrice = USDPrice;
    //     // info.currentRound = currentRound;
    //     // info.totalTC = totalTC;
    //     // info.totalSpentUSD = totalSpentUSD;
    //     // info.totalPurchasedTC = totalPurchasedTC;
    //     // info.totalPurchasedTCSinceLastRound = totalPurchasedTCSinceLastRound;
    //     // info.totalTCGivenForReferrals = totalTCGivenForReferrals;
    //     // return info;
	// }

	function verifySetReferralCode(string calldata myReferralCode) external view returns (uint) {
		IPresale Presale = IPresale(address(this));
		uint _userID = Presale.userIDs(msg.sender);

        require(
            _userID != 0,
            "CROWDFUND | REGISTRATION: You must participate in the Presale before you can set a Referral Code."
        );

        require(
            Presale.referralCodes(myReferralCode) == 0 && _userID != 0,
            "CROWDFUND | SET REFERRAL CODE: Provided code is already in use! Please pick a different one."
        );

		string memory _referralCode = Presale.getUserById(_userID).referralCode;
        
        require(
            Caffeinated.stringsAreIdentical(_referralCode, "")
            || Presale.referralCodes(myReferralCode) == 0,
            string.concat(
                "CROWDFUND | REFERRAL CODE ALREADY SET: Can only set your Referral Code once. Yours: ", 
                _referralCode
            )
        );

		return _userID;
    }

	function calcTwoHalfPctReferralBonus(uint amount) public pure returns (uint) {
        return 25 * amount / 1000; // == +2.5%
    }

    function calcReferralCode(uint toPurchase, uint userID, string calldata referralCode) external returns (uint) {
		IPresale Presale = IPresale(address(this));

        // @dev
        // If a Referral Code was supplied, find the owner.
        // If the owner is found, give each person 2.5% bonus TC.
        if (bytes(referralCode).length > 0) {

            // If the Referral Code belongs to a registered user
            // and not to an empty userNum, then give the bonus.
            PresaleLib_structs.UserStruct memory _referralOwner = Presale.getUserById(Presale.referralCodes(referralCode));
            PresaleLib_structs.UserStruct memory _referralUser = Presale.getUserById(userID);

            if (
                Presale.referralCodes(referralCode) != 0
                && _referralOwner.isRegistered
                && !Caffeinated.stringsAreIdentical(_referralUser.referralCode, referralCode)
            ) {
                uint _referralBonusEachPerson = calcTwoHalfPctReferralBonus(toPurchase);
            
                _referralUser.balance.current += _referralBonusEachPerson;
                _referralUser.balance.bonusFromReferralsOthers += _referralBonusEachPerson;
                _referralUser.balance.aggregate += _referralBonusEachPerson;

                _referralOwner.balance.current += _referralBonusEachPerson;
                _referralOwner.balance.bonusFromReferralsYours += _referralBonusEachPerson;
                _referralOwner.balance.aggregate = _referralBonusEachPerson;

				Presale._setUser(_referralOwner);
				Presale._setUser(_referralUser);

                return _referralBonusEachPerson * 2;
            }
        }

        return 0;
    }

    function _verifyPurchase(uint expectedRound, address account) public view {
		IPresale Presale = IPresale(address(this));
		
	require(
            !Presale.contractIsFrozen(),
            "CROWDFUND | PURCHASE ERROR: The contract has been frozen."
        );

        require(
            Presale.TC().balanceOf(address(this)) >= Presale.requiredTC(),
            "CROWDFUND | PURCHASE ERROR: Insufficient TC balance."
        );

        uint _contractUserID = Presale.contractUserID();
        PresaleLib_structs.UserStruct memory _user = Presale.getUserById(_contractUserID);

        require(
            _user.balance.current > 0,
            "CROWDFUND | PURCHASE ERROR: All available TC for this CROWDFUND has already been purchased."
        );

		uint _currentRound = Presale.currentRound();

        // Pseudo-`verifyRound` question.
        // If the max uint is passed, bypass this verification.
        if (expectedRound < type(uint).max) {
            require(
                _currentRound == expectedRound,
                string.concat(
                    "CROWDFUND | PURCHASE ERROR: The current round of TC price (",
                    Caffeinated.uintToString(_currentRound),
                    ") did not match the round expected by the transaction (",
                    Caffeinated.uintToString(expectedRound),
                    ")."    
                )
            );
        }
        
        require(
            _currentRound < 3 || block.timestamp >= Presale.timeStartPublicRounds(),
            "CROWDFUND | PUBLIC ROUNDS: Haven't yet opened."
        );

		IBotPool BotPool = Presale.BotPool();

        // @Beta>>
        // Lock down the Presale to only users in the `permittedUser` list in BotController.
        // require(
        //     (
        //         BotPool.userVals(account, isPermittedUser) != 0
        //         || BotPool.userVals(address(BotPool), isPermittedUser) != 0
        //         || BotPool.userVals(address(this), isPermittedUser) != 0
        //         || (BotPool.userVals(account, isSanctionedUser) == 0 && _currentRound > 0)
        //     ),
        //     "CROWDFUND | PERMITTED ERROR: User is not eligible to take part in the crowdfund."
        // );

        // @Alpha-v2>>
        IBotController BotController = Presale.BotPool().botController();
        require(
            (
                !BotController.sanctionedUser(account)
                && (
                    BotController.permittedUser(address(BotPool))
                    || BotController.permittedUser(address(this))
                    || BotController.permittedUser(account)
                )
            ),
            "CROWDFUND | PERMITTED ERROR: User is not eligible to take part in the crowdfund."
        );
    }


	function verifyVestTC(uint amountTC, uint8 yrs, uint userID) external view returns (uint) {
		IPresale Presale = IPresale(address(this));
		IBotPool BotPool = Presale.BotPool();
        
        require(address(BotPool) != address(0), "CROWDFUND | VEST: BotPool has not been deployed and linked yet.");
        require(yrs > 0 && yrs < Presale.t(), "CROWDFUND | VEST: Only valid for 1-4 years.");

        _verifyPurchase(
            type(uint).max
			/* Effectively bypassing this check since no purchase is actually taking place */,
            msg.sender
        );

        uint _balance = Presale.getUserById(userID).balance.current;

        require(
            _balance > 0,
            "CROWDFUND | VEST: No balance available to vest."
        );

        if (amountTC > _balance) {
            amountTC = _balance;
        }

		return amountTC;
	}


    function _verifyProcessRequest(uint _amountUSD) external view returns (bytes1 _tokenSpend) {
        IPresale Presale = IPresale(address(this));
        IERC20 USDC = Presale.USDC();
        IERC20 USDCe = Presale.USDCe();

        if (
            USDC.allowance(msg.sender, address(this)) >= _amountUSD
            && USDC.balanceOf(msg.sender) >= _amountUSD
        ) {
            _tokenSpend = bytes1(0x01);
        }
        else if (
            USDCe.allowance(msg.sender, address(this)) >= _amountUSD
            && USDCe.balanceOf(msg.sender) >= _amountUSD
        ) {
            _tokenSpend = bytes1(0x02);
        }

        require(
            _tokenSpend != bytes1(0x01) || _tokenSpend != bytes1(0x02),
            "CROWDFUND | PURCHASE ERROR: Must provide enough allowance and have sufficient balance to cover the USD to be spent."
        );

        return _tokenSpend;
    }
    

}
