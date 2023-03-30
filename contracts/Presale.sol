// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./Baked.sol";

import "./libraries/Caffeinated.sol";
import "./libraries/PresaleLib_util.sol";
import "./libraries/PresaleLib_structs.sol";

// import "./interfaces/AggregatorV3Interface.sol";
// import "./interfaces/IBotController.sol";
import "./interfaces/IBotPool.sol";
import "./interfaces/IERC20T.sol";
import "./interfaces/IFoundersVesting.sol";
import "./interfaces/IPresale.sol";

// import "hardhat/console.sol";

contract Presale is Baked {

    event Purchase(address indexed from, address indexed to, uint value);
    event Extinguished(uint tcTotal);
    event Vested(address indexed from, address indexed to, uint value, uint pctVested);
    event RoundUpdate(uint newRound, uint tcSoldSinceLastRound);
    event MigrationStatus(uint completedAccounts, uint totalAccounts, uint tcTotal, uint tccTotal);
    event MigrationDone();

    string public constant version = "2023-02-28 | Beta";
    IERC20T public /* immutable */ TC;
    IERC20T public TCC;

    // IERC20(0x5425890298aed601595a70AB815c96711a31Bc65); FUJI
    // IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E); MAINNET
    IERC20 public constant USDC = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    
    // IERC20(0x45ea5d57BA80B5e3b0Ed502e9a08d568c96278F9); FUJI
    // IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664); MAINNET
    IERC20 public constant USDCe = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    

    // AggregatorV3Interface public constant priceFeed = AggregatorV3Interface(0x0A77230d17318075983913bC2145DB16C7366156); // AVAX mainnet - AVAX/USD

    uint public constant oneHundredPct = Caffeinated.precision;
    uint public constant secPerWeek = 604800;
    uint public timeStartPublicRounds;
    uint public normalizedTC;
    uint public normalizedUSD = 10 ** 6;
    uint public constant normalizedAVAX = 10 ** 18;
    uint public immutable extraBonusThreshold;
    uint public constant extraBonusPct = 2 * oneHundredPct / 100;
    uint public immutable extraBonusInitialCliff;
    // uint public constant nftSilverPct = 50 * oneHundredPct / 100;
    // uint public constant nftGoldPct = oneHundredPct;
    // uint public constant nftLegendaryPct = nftSilverPct;
    // uint public constant nftInsanePct = nftGoldPct;
    uint8 public constant t = _t; // MUST == BotPool.t()
    uint[t] public nftAmounts;
    // string public constant nftInit = "None";
    // string public constant nftSilver = "Silver";
    // string public constant nftGold = "Gold";
    uint public constant fiftyPct = 50 * oneHundredPct / 100;

    uint public constant maxSingleLoopSize = 1500;
    uint public constant maxUsers = maxSingleLoopSize ** 3;

    uint8 public constant n = _n; // Number of Rounds
    uint[n] public TCRounds = [ 2100000, 2100000, 4200000, 4200000, 4200000, 4200000 ];
    uint[n] public USDPrice = [ woah there, not so fast! you want prices? come to the 420 meeting ];
    uint public currentRound = 1;
    uint public totalTC;
    uint public requiredTC;
    uint public requiredTCC;
    uint public tcDisbursed;
    uint public totalSpentUSD;
    uint public totalPurchasedTC;
    uint public totalPurchasedTCSinceLastRound;

    uint public constant contractUserID = 1;
    uint public lastUserTransferred = contractUserID + 1;
    IBotPool public BotPool;
    // IBotController public botController;
    address public teamWallet;
    address public immutable foundersVesting;
    address public treasuryWallet_;
    uint public timeEnd;

    // Referral code --> UserID
    mapping(string => uint) public referralCodes;

    mapping(address => uint) public userIDs;
    
    // private on purpose
    // We found that when grabbing a Struct from here
    // that it gets returned from the auto-generated function
    // without any nested arrays. If we didn't have arrays
    // inside the struct we could use the auto-generated
    // `view` function. In our case because we want nested arrays
    // we require using a getter.
    PresaleLib_structs.UserStruct[] private users_;
    function numUsers_() public view returns (uint) {
        // Minus 1 because users_[0] is the default/empty/unregistered user
        return users_.length - 1;
    }

    uint public totalTCGivenForReferrals;

    IPresale.Contribution[] contributions;

    address[] public existingOwners;
    uint[] public existingTCBalances;
    uint[] public existingTCCBalances;
    uint public ownerCompleted;
    uint public ownerCount; // immutable

    // TC, USDC, USDC.e
    constructor(address _tc, address _teamWallet, address _foundersVesting) {
        adminWallet = msg.sender;
        teamWallet = _teamWallet;
        foundersVesting = _foundersVesting;
        // botController = _botController;

        timeEnd = block.timestamp + (26 weeks) + (1 days);

        // USDC = IERC20(_tokens[0]);
        TC = IERC20T(_tc);
        // USDCe = IERC20(_tokens[2]);

        treasuryWallet_ = TC.treasuryWallet();

        normalizedTC = 10 ** TC.decimals();
        nftAmounts = [0, 4200 * normalizedTC, 16900 * normalizedTC, 42000 * normalizedTC, 69000 * normalizedTC];

        extraBonusThreshold = 100000 * normalizedTC;
        extraBonusInitialCliff = extraBonusPct * extraBonusThreshold / oneHundredPct;
    
        for (uint8 i; i < TCRounds.length; ++i) {
            TCRounds[i] *= normalizedTC;
            totalTC += TCRounds[i];
        }

        totalTC = totalTC * 105 / 100;
        requiredTC = totalTC * 112 / 100;
        

        // user 0 must be empty
        users_.push(PresaleLib_structs.emptyUser());

        uint originUserID = _addUser(address(this));
        users_[originUserID].balance.current = totalTC;
        users_[originUserID].balance.aggregate = totalTC;

        _addUser(teamWallet);

        contractIsFrozen = true;
    }




    // ### EXISTING BALANCES FUNCTIONS ###
    function rememberExistingOwners(address[] calldata _existingOwners) external _teamAuth {
        require(ownerCount == 0, "CROWDFUND | REMEMBER: Already have a memory. (1)");
        // require(
        //     _existingOwners.length == _existingTCBalances.length,
        //     "CROWDFUND | REMEMBER: Owners and TC Balances lists are not the same length."
        // );

        existingOwners = _existingOwners;
        // existingTCBalances = _existingTCBalances;
    }

    function rememberExistingTCBalances(uint[] calldata _existingTCBalances) external _teamAuth {
        require(
            ownerCount == 0
            && existingOwners.length != 0
            && existingTCBalances.length == 0,
            "CROWDFUND | REMEMBER: Already have a memory. (2)"
        );
        require(
            existingOwners.length == _existingTCBalances.length,
            "CROWDFUND | REMEMBER: Owners and TC Balances lists are not the same length."
        );

        // existingOwners = _existingOwners;
        existingTCBalances = _existingTCBalances;
    }

    function rememberExistingTCCBalances(uint[] calldata _existingTCCBalances) external _teamAuth {
        require(
            ownerCount == 0
            && existingOwners.length != 0
            && existingTCCBalances.length == 0,
            "CROWDFUND | REMEMBER: TC Owners must be first and only once."
        );
        require(
            existingOwners.length == _existingTCCBalances.length,
            "CROWDFUND | REMEMBER: Owners and TCC Balances lists are not the same length."
        );
        existingTCCBalances = _existingTCCBalances;
        ownerCount = existingOwners.length;
    }

    // Moving this to a library ADDS +0.7 Kb in bytecode.
    // DO NOT MOVE TO LIBRARY
    function loopExistingBalances() external {

        // console.log(string.concat("ownerCount:     ", Caffeinated.uintToString(ownerCount), " | existingOwners.length: ", Caffeinated.uintToString(existingOwners.length)));
        // console.log(string.concat("ownerCompleted: ", Caffeinated.uintToString(ownerCompleted), " | existingOwners.length: ", Caffeinated.uintToString(existingOwners.length)));
        
        require(ownerCount > 0, "CROWDFUND | SETUP: No balances remembered.");
        require(ownerCompleted < ownerCount, "CROWDFUND | SETUP: Already completed.");

        uint _existingTC;
        uint _existingTCC;
        uint i = ownerCompleted;

        for (; i < existingOwners.length; ++i) {
            if (gasleft() < 500000) {
                ownerCompleted = i;

                // +5% for referral codes
                _existingTC = _existingTC * 105 / 100;

                // +12% max possible global bonus TC for vesting
                requiredTC += (_existingTC * 112 / 100);
                requiredTCC += _existingTCC;
                break;
            }

            uint userID = _addUser(existingOwners[i]);
            users_[userID].balance.current      = existingTCBalances[i];
            users_[userID].balance.aggregate    = existingTCBalances[i];
            users_[userID].balance.tcc          = existingTCCBalances[i];
            _existingTC     += users_[userID].balance.current;
            _existingTCC    += users_[userID].balance.tcc;
        }

        ownerCompleted = i;

        // +5% for referral codes
        _existingTC = _existingTC * 105 / 100;

        // +12% max possible global bonus TC for vesting
        requiredTC += (_existingTC * 112 / 100);
        requiredTCC += _existingTCC;
        

        emit MigrationStatus(ownerCompleted, ownerCount, requiredTC, requiredTCC);

        if (ownerCompleted == ownerCount) {
            emit MigrationDone();
        }
    }

    function _setUser(PresaleLib_structs.UserStruct memory _user) _selfAuth external {
        users_[_user.userID] = _user;
    }




    // ### AUTHORISATION FUNCTIONS ###
    modifier _teamAuth() {
        require(
            msg.sender == adminWallet || msg.sender == teamWallet,
            "CROWD | AUTH: Sender is not the Admin Wallet."
        );
        _;
    }

    modifier _selfAuth() {
        require(
            msg.sender == address(this),
            "CROWD | AUTH: No external execution."
        );
        _;
    }




    // ### SETTER FUNCTIONS ###
    function setBotPool(address _BotPool) external _teamAuth {
        // If we use a script to set BotPool,
        // delete the script's admin privileges
        // after execution.
        if (address(BotPool) == address(0)) {
            adminWallet = teamWallet;
        }
        else {
            TC.approve(address(BotPool), 0);
            TCC.approve(address(BotPool), 0);
        }
        
        BotPool = IBotPool(_BotPool);
        TCC = BotPool.tcc(); // @Beta>> BotPool.TCC();

        approve();
        // TC.approve(address(BotPool), type(uint).max);
        // TCC.approve(address(BotPool), type(uint).max);
    }

    // TODO: Needs testing
    function setTimeStartPublicRounds(uint timestamp) external _teamAuth {
        require(
            currentRound < 3
            || block.timestamp < timeStartPublicRounds,
            "PRESALE | PUBLIC ROUNDS: Can only be started once."
        );

        // Team can update the `timeStartPublicRounds` multiple times
        // until it passes. `currentRound` should only be updated once.
        timeStartPublicRounds = timestamp;

        if (currentRound < 3) {
            currentRound = 3;
            emit RoundUpdate(currentRound, totalPurchasedTCSinceLastRound);
            delete totalPurchasedTCSinceLastRound;
        }
    }

    function setTeamWallet(address newTeamWallet) external _adminAuth {
        teamWallet = newTeamWallet;
    }

    function setTreasuryWallet(address newTreasuryWallet) external _adminAuth {
        require(
            newTreasuryWallet != address(0),
            "PRESALE | SET TREASURY: Cannot be set to the 0 address."
        );

        treasuryWallet_ = newTreasuryWallet;
    }

    function walletChange(address newWallet) external {
        uint userID = userIDs[msg.sender];

        require(
            userID != 0,
            "PRESALE | WALLET CHANGE: You are not registered."
        );

        require(
            users_[userID].balance.vested == 0,
            "PRESALE | WALLET CHANGE: Wallet address change can only be done before Vesting."
        );

        userIDs[newWallet] = userID;
        delete userIDs[msg.sender];

        users_[userID].adresse = newWallet;
    }




    // ### GETTER FUNCTIONS ###
    function getInfo() external view returns (IPresale.Info memory info) {
        // info.user = users_[userIDs[account]];
        info.numUsers = users_.length;
        info.TCRounds = TCRounds;
        info.USDPrice = USDPrice;
        info.currentRound = currentRound;
        info.totalTC = totalTC;
        info.totalSpentUSD = totalSpentUSD;
        info.totalPurchasedTC = totalPurchasedTC;
        info.totalPurchasedTCSinceLastRound = totalPurchasedTCSinceLastRound;
        info.totalTCGivenForReferrals = totalTCGivenForReferrals;
        return info;
    }

    function getUser(address account) external view returns (PresaleLib_structs.UserStruct memory) {
        return users_[userIDs[account]];
    }

    function getUserById(uint index) external view returns (PresaleLib_structs.UserStruct memory) {
        require(index < users_.length, "PRESALE | GET USER: Invalid index used as User ID.");
        return users_[index];
    }

    function getUserList() external view returns (PresaleLib_structs.UserStruct[] memory) {
        return users_;
    }

    function getContributions() external view returns (IPresale.Contribution[] memory) {
        return contributions;
    }

    // TODO: Needs testing
    function setReferralCode(string calldata myReferralCode) external {

        uint _userID = userIDs[msg.sender];
        if (_userID > 0) {
            if (bytes(myReferralCode).length == 0) {
                string memory _myReferralCode = string(abi.encodePacked(msg.sender));

                // If the referral code that equals a string of your address
                // is already in use, erase the entry, allow the other
                // user to set a new code, and set your code to a string
                // of your address.
                if (referralCodes[_myReferralCode] != 0) {
                    
                    // Delete the user's referral code
                    delete users_[referralCodes[_myReferralCode]].referralCode;

                    // Delete the referral code to userID
                    delete referralCodes[_myReferralCode];
                }
            }

            require(
                PresaleLib_util.verifySetReferralCode(myReferralCode)
                ==
                _userID,
                "RCUID"
            );
            
            users_[_userID].referralCode = myReferralCode;
            referralCodes[myReferralCode] = _userID;
        }
    }

        // require(
        //     userIDs[msg.sender] != 0,
        //     "CROWDFUND | REGISTRATION: You must participate in the Presale before you can set a Referral Code."
        // );

        // require(
        //     referralCodes[myReferralCode] == 0 && userIDs[msg.sender] != 0,
        //     "CROWDFUND | SET REFERRAL CODE: Provided code is already in use! Please pick a different one."
        // );
        
        // require(
        //     Caffeinated.stringsAreIdentical(users_[userIDs[msg.sender]].referralCode, "")
        //     || referralCodes[myReferralCode] == 0,
        //     string.concat(
        //         "CROWDFUND | REFERRAL CODE ALREADY SET: Can only set your Referral Code once. Yours: ", 
        //         users_[userIDs[msg.sender]].referralCode
        //     )
        // );

        // if (bytes(myReferralCode).length == 0) {
        //     string memory _myReferralCode = string(abi.encodePacked(msg.sender));
        //     users_[userIDs[msg.sender]].referralCode = _myReferralCode;
        //     referralCodes[_myReferralCode] = userIDs[msg.sender];
        //     return;
        // }
        
        // users_[userIDs[msg.sender]].referralCode = myReferralCode;
        // referralCodes[myReferralCode] = userIDs[msg.sender];
    // }




    // ### TC PURCHASE FUNCTIONS ###
    function _addUser(address account) private returns (uint) {
        uint userID = userIDs[account];

        if (users_[userID].isRegistered) {
            return userID;
        }

        require(
            users_.length < maxUsers,
            string.concat(
                "CROWDFUND | ADMISSION ERROR: The maximum number of ",
                Caffeinated.uintToString(maxUsers),
                " users has been reached."
            )
        );

        userID = users_.length;
        userIDs[account] = userID;
        users_.push(PresaleLib_structs.emptyUser());
        users_[userID].adresse = account;
        users_[userID].isRegistered = true;

        // auto-set referral code
        // @dev nah, make the user do it themselves
        // @dev they'll feel better about that anyway
        // string memory _myReferralCode = string(abi.encodePacked(msg.sender));
        // users_[userID].referralCode = _myReferralCode;
        // referralCodes[_myReferralCode] = userID;

        return userID;
    }

    // function _verifyPurchase(uint expectedRound, address account) private view {

    //     require(
    //         TC.balanceOf(address(this)) >= requiredTC,
    //         "CROWDFUND | PURCHASE ERROR: Insufficient TC balance."
    //     );

    //     require(
    //         users_[contractUserID].balance > 0,
    //         "CROWDFUND | PURCHASE ERROR: All available TC for this CROWDFUND has already been purchased."
    //     );

    //     require(
    //         currentRound == expectedRound,
    //         string.concat(
    //             "CROWDFUND | PURCHASE ERROR: The current round of TC price (",
    //             Caffeinated.uintToString(currentRound),
    //             ") did not match the round expected by the transaction (",
    //             Caffeinated.uintToString(expectedRound),
    //             ")."    
    //         )
    //     );
        
    //     require(
    //         currentRound < 3 || block.timestamp >= timeStartPublicRounds,
    //         "CROWDFUND | PUBLIC ROUNDS: Haven't yet opened."
    //     );

    //     // Lock down the Presale to only users in the `permittedUser` list in BotController.
    //     require(
    //         (
    //             BotPool.userVals(account, isPermittedUser) != 0
    //             || BotPool.userVals(address(BotPool), isPermittedUser) != 0
    //             || BotPool.userVals(address(this), isPermittedUser) != 0
    //             || (BotPool.userVals(account, isSanctionedUser) == 0 && currentRound > 0)
    //         ),
    //         "CROWDFUND | PERMITTED ERROR: User is not eligible to take part in the crowdfund."
    //     );
    // }

    function _updateRound(uint _purchasedTC) private {
        totalPurchasedTC += _purchasedTC;
        totalPurchasedTCSinceLastRound += _purchasedTC;

        if (totalPurchasedTCSinceLastRound == TCRounds[currentRound - 1]) {
            
            ++currentRound;
            emit RoundUpdate(currentRound, totalPurchasedTCSinceLastRound);
            delete totalPurchasedTCSinceLastRound;

            if (currentRound > 2) {
                timeStartPublicRounds = block.timestamp + secPerWeek;
            }
        }
    }

    // function calcTwoHalfPctReferralBonus(uint amount) public pure returns (uint) {
    //     return 25 * amount / 1000; // == +2.5%
    // }

    // function calcReferralCode(uint toPurchase, uint userID, string calldata referralCode) private {
    //     // // @dev
    //     // // If a Referral Code was supplied, find the owner.
    //     // // If the owner is found, give each person 2.5% bonus TC.
    //     // if (bytes(referralCode).length > 0) {

    //     //     // If the Referral Code belongs to a registered user
    //     //     // and not to an empty userNum, then give the bonus.
    //     //     PresaleLib_structs.UserStruct memory _referralOwner = users_[referralCodes[referralCode]];
    //     //     PresaleLib_structs.UserStruct memory _referralUser = users_[userID];


    //     //     if (
    //     //         referralCodes[referralCode] != 0
    //     //         && _referralOwner.isRegistered
    //     //         && !Caffeinated.stringsAreIdentical(_referralUser.referralCode, referralCode)
    //     //     ) {
    //     //         uint _referralBonusEachPerson = calcTwoHalfPctReferralBonus(toPurchase);

    //     //         _referralUser.balance += _referralBonusEachPerson;
    //     //         _referralUser.balanceBonusFromUsingReferrals += _referralBonusEachPerson;
    //     //         _referralUser.balanceTotalEver += _referralBonusEachPerson;

    //     //         _referralOwner.balance += _referralBonusEachPerson;
    //     //         _referralOwner.balanceBonusFromYourReferrals += _referralBonusEachPerson;
    //     //         _referralOwner.balanceTotalEver = _referralBonusEachPerson;

    //     //         totalTCGivenForReferrals += (_referralBonusEachPerson * 2);
    //     //     }
    //     // }
    //     totalTCGivenForReferrals += PresaleLib_util.calcReferralCode(toPurchase, userID, referralCode)
    // }

    function _processRequest(
        string calldata referralCode,
        uint expectedRound,
        uint amountUSD
    ) private returns (
        uint purchasedTC,
        uint spentUSD
    ) {
        require(
            amountUSD > 0,
            "CROWDFUND | PURCHASE ERROR: Cannot purchase 0 TC."
        );

        uint userID = _addUser(msg.sender);

        PresaleLib_util._verifyPurchase(expectedRound, msg.sender);

        bytes1 tokenSpend = PresaleLib_util._verifyProcessRequest(amountUSD);

        uint toPurchase = amountUSD * normalizedTC / USDPrice[currentRound - 1];
        uint maxCanPurchase = TCRounds[currentRound - 1] - totalPurchasedTCSinceLastRound;

        totalTCGivenForReferrals += PresaleLib_util.calcReferralCode(toPurchase, userID, referralCode);
        
        uint _purchasedTC = toPurchase > maxCanPurchase ? maxCanPurchase : toPurchase;
        users_[userID].balance.current += _purchasedTC;
        users_[userID].balance.aggregate += _purchasedTC;
        users_[contractUserID].balance.current -= _purchasedTC;
        emit Purchase(address(this), msg.sender, _purchasedTC);

        uint _spentUSD = _purchasedTC * USDPrice[currentRound - 1] / normalizedTC;

        if (tokenSpend == 0x01) {
            USDC.transferFrom(msg.sender, address(this), _spentUSD);
            users_[userID].spent.usdc += _spentUSD;
        }
        else if (tokenSpend == 0x02) {
            USDCe.transferFrom(msg.sender, address(this), _spentUSD);
            users_[userID].spent.usdc_e += _spentUSD;
        }
        else {
            revert("CROWDFUND | PURCHASE ERROR: Could not determine the token used to purchase TC.");
        }

        totalSpentUSD += _spentUSD;
        
        contributions.push(IPresale.Contribution(msg.sender, _spentUSD, _purchasedTC));
        _updateRound(_purchasedTC);
        return (_purchasedTC, _spentUSD);
    }

    function requestUsingAmountTC(
        uint amountTC,
        uint expectedRound,
        string calldata referralCode
    ) external returns (
        uint purchasedTC,
        uint spentUSD
    ) {
        return 
            _processRequest(
                referralCode,
                expectedRound,
                USDPrice[currentRound - 1] * amountTC / normalizedUSD
            );
    }

    function requestUsingAmountUSDC(
        uint amountUSD,
        uint expectedRound,
        string calldata referralCode
    ) external returns (
        uint purchasedTC,
        uint spentUSD
    ) {
        return 
            _processRequest(
                referralCode,
                expectedRound,
                amountUSD
            );
    }

    // For users who want to vest some amount of TC.
    // The basic math of this function has been well tested in Remix:
    // https://discord.com/channels/941687973651550289/1046488693961130057/1054721313337511966
    // https://discord.com/channels/941687973651550289/1046488693961130057/1054741985845579776
    // We should also test it in Hardhat on a forked Avalanche chain.
    function vestTC(uint amountTC, uint8 yrs /* MUST be 1 to 4 */) external {
        uint userID = _addUser(msg.sender);

        amountTC = PresaleLib_util.verifyVestTC(amountTC, yrs, userID);
        
        // +10% bonus
        // console.log(string.concat("CROWDFUND original amountTC: ", Caffeinated.uintToString(amountTC)));

        uint prevBalanceVested = users_[userID].balance.vested;
        users_[userID].balance.vested += amountTC;

        // Add to the `amountTC` the bonus amount, depending on the percentage of their balance in only CROWDFUND (exclude TC balance in BotPool).
        uint pctToVest = Caffeinated.toPercent(amountTC, users_[userID].balance.current); // divide by 10 to get 10% max bonus

        // Before modifying the `amountTC`, subtract from the user's balance their amount.
        users_[userID].balance.current -= amountTC;

        bool nftRewarded;
        for (uint8 i = yrs; i > 0; --i) {
            if (
                pctToVest >= oneHundredPct
                && amountTC >= nftAmounts[i]
                && !users_[userID].nftRewards[i]
            ) {
                users_[userID].nftRewards[i] = true;
                nftRewarded = true;
                break;
            }
            // Can't get any lower tier reward on Year 1; thus `i` must be >= 2.
            else if (
                i >= 2
                && pctToVest >= fiftyPct
                && amountTC >= nftAmounts[i - 1]
                && !users_[userID].nftRewards[i - 1]
            ) {
                users_[userID].nftRewards[i - 1] = true;
                nftRewarded = true;
                break;
            }
        }

        if (nftRewarded && !users_[userID].nftRewards[0]) {
            bool allNftsRewarded = true;
            for (uint8 y = 1; y < t; ++y) {
                allNftsRewarded = users_[userID].nftRewards[y];
                if (!allNftsRewarded) break;
            }

            if (allNftsRewarded) {
                users_[userID].nftRewards[0] = allNftsRewarded;
            }
        }
        
        // TC to add as bonus based on the percentage of the TC representative of the User's current Crowdfund balance.
        // Gives +10% for the first year and +5% for every subsequent year.
        uint256 bonusTC = amountTC * pctToVest * (yrs + 1) / 20 / oneHundredPct; // <-- IMPORTANT
        
        // Give a 2% if the user has vested over 100,000 TC.
        if (users_[userID].balance.vested >= extraBonusThreshold) {
            // Is THIS vesting when the user goes over the 100,000 TC threshold?
            if (prevBalanceVested < extraBonusThreshold) {
                // Give flat 2,000 TC if the user has reached a total amount vested of >100,000 TC on THIS vesting.
                // Add to it the 2% bonus on the amount over 100,000 TC.
                bonusTC +=
                    extraBonusInitialCliff
                        + (
                            (users_[userID].balance.vested - extraBonusThreshold)
                            * extraBonusPct / oneHundredPct
                        );
            }
            else {
                // Give +2% if the user has reached a total amount vested of >100,000 TC
                // and THIS vesting isn't when it occurred. Meaning it occurred previously
                // and we can safely apply the 2% bonus to the entire `amountTC`.
                bonusTC += amountTC * extraBonusPct / oneHundredPct;
            }
        }

        users_[userID].balance.bonus += bonusTC;
        amountTC += bonusTC;

        // Make sure to subtract from `requiredTC` the total amount of TC being sent to BotPool,
        // not only the amount impacting the user's balance.
        requiredTC -= amountTC;

        uint tcBalBefore = TC.balanceOf(address(this));
        uint tccBalBefore = TCC.balanceOf(address(this));

        if (users_[userID].balance.tcc > 0) {
            TCC.transfer(address(BotPool), users_[userID].balance.tcc);
            requiredTCC -= users_[userID].balance.tcc;
        }
        
        BotPool.depositPresale(msg.sender, amountTC, yrs, users_[userID].balance.tcc);

        require(
            tcBalBefore - TC.balanceOf(address(this)) == amountTC,
            "CROWDFUND | VEST: Incorrect amount of TC sent to BotPool."
        );

        require(
            tccBalBefore - TCC.balanceOf(address(this)) == users_[userID].balance.tcc,
            "CROWDFUND | VEST: Incorrect amount of TCC sent to BotPool."
        );
        
        tcDisbursed += amountTC;
        delete users_[userID].balance.tcc;
        emit Vested(msg.sender, address(BotPool), amountTC, pctToVest);
    }




    // ### PRESALE END FUNCTIONS ###
    function _transferPurchasedTC() private returns (bool) {
        TC.approve(address(BotPool), type(uint).max);

        uint nextUsers = lastUserTransferred + maxSingleLoopSize;
        // uint numUsers = users_.length;

        if (nextUsers > users_.length) {
            nextUsers = users_.length;
        }

        uint i = lastUserTransferred;
        uint _tcDisbursed;

        for (; i < nextUsers; ++i) {
            if (gasleft() < 350000) {
                tcDisbursed += _tcDisbursed;
                break;
            }

            address account = users_[i].adresse;
            if (users_[i].balance.current > 0 || users_[i].balance.tcc > 0) {
                // BotPool.cancelPendingTransfers(account);

                // @Alpha-v2>>
                // if (BotPool.userVals(account, isSanctionedUser) != 0) {
                if (BotPool.botController().sanctionedUser(account)) {
                    USDC.transfer(account, users_[i].spent.usdc);
                    USDCe.transfer(account, users_[i].spent.usdc_e);
                }
                else {
                    // TC.transfer(users_[i].userAddress, users_[i].balance);
                    
                    BotPool.depositPresale(
                        account,
                        users_[i].balance.current,
                        0,
                        users_[i].balance.tcc
                    );

                    _tcDisbursed += users_[i].balance.current;
                }

                requiredTC -= users_[i].balance.current;
                delete users_[i].balance;
                delete users_[i].balance.tcc;
            }
        }

        lastUserTransferred = i;
        tcDisbursed += _tcDisbursed;
        return lastUserTransferred >= users_.length;
    }

    // TEAM: Make sure to run `await this.BotController.functions.setPermittedUsersList([this.BotPool.address], [1], this.txnParams);`
    //       before ending the Crowdfund. The BotPool address itself must be added to the BotController's `permittedUsers` list
    //       in order for users to be able to have their TC transferred to the BotPool.
    function endCrowdfund(address newCROWDFUND) external {

        require(
            address(BotPool) != address(0),
            "CROWDFUND | END: BotPool has not been deployed and linked yet."
        );

        require(
            msg.sender == adminWallet || timeEnd < block.timestamp,
            "AUTH ERROR: `endCrowdfund` can only be called by the Admin Wallet."
        );

        _setContractIsFrozen(true);
        // BotPool.setPresale(address(BotPool)); // replaced by better logic

        if (!_transferPurchasedTC()) {
            return;
        }

        // Want to make sure there's PLENTY of gas to run through the rest.
        if (gasleft() < 3000000) {
            return;
        }

        uint USDCBalance = USDC.balanceOf(address(this));
        uint USDCeBalance = USDCe.balanceOf(address(this));
        uint TCBalance = TC.balanceOf(address(this));
        uint TCCBalance = TCC.balanceOf(address(this));

        if (USDCBalance > 0) {
            USDC.transfer(foundersVesting, USDCBalance / 10);
            USDC.transfer(treasuryWallet_, USDC.balanceOf(address(this)));
        }

        if (USDCeBalance > 0) {
            USDCe.transfer(foundersVesting, USDCeBalance / 10);
            USDCe.transfer(treasuryWallet_, USDCe.balanceOf(address(this)));
        }

        if (TCBalance > 0) {
            TC.transfer(treasuryWallet_, TCBalance);
        }

        if (TCCBalance > 0) {
            TCC.transfer(treasuryWallet_, TCCBalance);
        }

        BotPool.setPresaleEnded();

        if (msg.sender != adminWallet) {
            delete newCROWDFUND;
        }

        // Verify the bool has been set on BotPool,
        // and if so, destroy this CROWDFUND smart contract.
        // @Beta>> if (BotPool.getVestingPlusSumOf(address(BotPool)) > 0) {
        if (BotPool.getVestedSum(0) > 0) {

            IFoundersVesting(foundersVesting).notifyUSDFunding();

            if (
                newCROWDFUND != address(0)
                && newCROWDFUND != address(this)
                && newCROWDFUND != adminWallet
            ) {
                BotPool.setPresale(newCROWDFUND);
            }

            // @Beta>> if (BotPool.vestingPlus(address(BotPool), 0) != 0) {
            if (BotPool.vested(0,0) != 0) {
                emit Extinguished(tcDisbursed);
                // selfdestruct(payable(treasuryWallet));
            }
        }
    }




    // ### MISC FUNCTIONS ###
    function approve() public {
        TC.approve(address(BotPool), type(uint).max);
        TCC.approve(address(BotPool), type(uint).max);
    }

    // Allows anyone to send tokens to the `treasuryWallet` that were accidentally received at this address.
    // ! This sends tokens to `msg.sender`, not `treasuryWallet`
    // ? Is the comment wrong or is the code wrong?
    function claimERC20(address _token) external {
        require(
            _token != address(TC)
            && _token != address(TCC)
            && _token != address(USDC)
            && _token != address(USDCe),
            "CROWDFUND | CLAIM: Cannot claim internal tokens."
        );
        IERC20T token = IERC20T(_token);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

}
