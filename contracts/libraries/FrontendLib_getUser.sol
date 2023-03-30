// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

// import "../constants.sol";
// uint constant lenFeeReductions = 11; // imported via INFTAdmin.sol
import "./NFTStructs.sol";

import "../interfaces/IBotController.sol";
import "../interfaces/IBotPool.sol";
import "../interfaces/IBotTrader.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/INFTAdmin.sol";
import "../interfaces/IFrontend.sol";

// import "../libraries/Caffeinated.sol";
// import "hardhat/console.sol";

library FrontendLib_getUser {

    uint8 public constant valuesLength = 6; // MUST == BotTraderLib_util.valuesLength

    // only used for frontend
    struct BotTraderReturns {
        uint total;
        uint deposited;
        int profit;
        uint fee;
        uint activeTradeStartingBalance;
        uint pendingDeposit;
        uint pendingWithdrawal;
        uint8 pendingWithdrawAll;
        uint withdrawNowMax;
        uint withdrawNowFee;
    }

    struct BotTraderStruct {
        address membership;             // address of the BotTrader that the user is assigned to
        uint userID;                    // `userID` number assigned in BotTrader
        uint pctOwnership;              // percentage of the BotTrader balance owned by this user
        int tradeStatus;                // `tradeStatus` from the BotTrader assigned to this user
    }

    struct ActiveTrade {
        uint startingBalance;           // initial balance
        uint profit;                    // subject to fee
        uint fee;                       // net-profit fee owed
        int pnl;                        // `balance` - `deposited`
    }

    /*
    struct Cumulative {
        int profit;                     // running total of all past profit
        uint fee;                       // running total of all net-profit fees charged
        int pnl;                        // running total of all net-profit (estimated)
    }
    */

    struct Pending {
        uint deposit;                   // amount of cash waiting to be deposited upon trade exit
        uint withdrawal;                // amount of cash waiting to be withdrawn upon trade exit
        bool withdrawAll;               // is the user requesting to withdraw all cash upon trade exit?
    }

    struct Withdraw {
        uint max;                       // `balance`, i.e maximum amount withdrawable pending or if the Bot is not in a trade
        uint fee;                       // fee owed if submitting a `Withdraw All Now` request
    }

    struct Cash {
        uint balance;                   // `total` - `fee`
        uint deposited;                 // initial balance
        uint total;                     // getBalanceOf from BotTrader
        uint profit;                    // amount they've made, subject to fee
        uint fee;                       // net-profit fee owed (only applies to the current trade)
        int pnl;                        // `balance` - `deposited`
        // Cumulative cumulative;          // `Cumulative` struct fields
        ActiveTrade activeTrade;        // `ActiveTrade` struct fields
        Pending pending;                // pending deposit and withdrawal
        Withdraw withdraw;              // the max amount available to withdraw *right now* with any penalties separately listed
        uint minReqBalance;             // minimum required cash to be on-deposit
        uint allowance;                 // amount of `cash` BotPool is permitted to TransferFrom() – cash
    }

    // only included to maintain consistency with the `cash --> withdraw --> max` path
    struct WithdrawTC {
        uint max;                       // maximum amount of TC that can be withdrawn
    }

    // only included to maintain consistency with the `cash --> pending` path
    struct PendingTC {
        uint withdrawal;
        bool withdrawAll;
    }

    // included to maintain consistency with the getInfo() `tc --> upkeep` path
    struct Upkeep {
        uint timeNext;                  // timestamp given in UNIX time of seconds when Upkeep weekly fee will next be charged
        uint timeLastIncreased;         // timestamp given in UNIX time of seconds when Upkeep weekly fee was last increased
        uint fee;                       // the amount of TC charged at next upkeep
        uint minWeeks;                  // number of weeks of {{ n Σ `fee` + 5% }} required
        uint reqFromZeroCash;           // required TC Upkeep payment to (pre-)pay for someone depositing cash into the Bot
        uint cumulative;                // total amount of TC the user has ever paid in Upkeep; resets upon Withdraw All
        uint daysRemaining;             // number of days remaining in upkeep the user has deposited
    }

    struct Vested {
        bool frozen;
        uint total;
        uint timeStart;
        uint timeLastClaimed;
        VestedAmount oneYear;
        VestedAmount twoYears;
        VestedAmount threeYears;
        VestedAmount fourYears;
    }

    struct VestedAmount {
        uint amount;
        uint timeEnd;
    }

    struct TC {
        uint total;                     // amount of this user's TC in BotPool
        uint balance;                   // amount of TC available to pay weekly upkeep
        uint operatingDeposit;          // required Operating Deposit
        Vested vested;
        PendingTC pending;
        WithdrawTC withdraw;            // maximum amount of TC that can be withdrawn
        uint minReqBalance;             // the minimum balance below which a Withdraw All will be forcibly triggered
        uint allowance;                 // amount BotPool is permitted to TransferFrom() – TC
        // uint allowanceDeadline;         // timestamp at which the `allowance` expires // no way to retrieve from the Token contract; must implement in JS
    }

    struct TCC {
        uint balance;                   // current TCC rewards in BotPool
        uint pctMultiplier;
        uint pctApr;
        uint rewardPerWeek;             // amount of TCC rewards earned in a week
        uint lastTimeRewarded;          // most recent time the TCC rewards were redeemed
    }

    struct NFT {
        uint level;                     // level of NFT 0-4 `getUserHighestLevel()`
        // uint[lenFeeReductions] levelBalances;           // balances of each level owned `getUserLevelBalances()`
        // NFTStructs.accountNFTs[] ownedList; // structs of (address, balance) for all NFTs owned `getAllUserNFTs()`
        uint pctFeeReduction;
    }

    struct GetUserStruct {
        address adresse;                // wallet address of this user
        address from;                   // address of the returned BotPool
        bool isRegistered;              // has this user ever deposited into BotPool?
        bool isBadUser;                 // has this user missed a Weekly Fee payment?
        uint8 pendingWithdrawAll;       // is the user requesting to withdraw everything upon trade exit?
        uint userID;                    // `userID` number assigned in BotPool
        uint inBotSince;                // timestamp of when the user deposited into the Bot
        uint pctOneHundred;
        BotTraderStruct botTrader;
        Upkeep upkeep;
        Cash cash;
        TC tc;
        TCC tcc;
        NFT nft;
    }

    function _calcDaysRemaining(
        address botPool,
        uint weeklyUserUpkeep,
        uint maxWeeks,
        uint TCRemaining,
        uint singleLoop
    ) public view returns (uint daysRemaining) {
        uint nextTimeGlobalUpkeep = IBotPool(botPool).nextTimeUpkeepGlobal();
        daysRemaining = nextTimeGlobalUpkeep < block.timestamp ? maxWeeks : ((nextTimeGlobalUpkeep - block.timestamp) / 1 days);
        uint nextWeeklyFee = weeklyUserUpkeep;
        for (uint i; i <= maxWeeks; ++i) {
            if (singleLoop > 0 && i > singleLoop) {
                break;
            }
            nextWeeklyFee += uint((weeklyUserUpkeep + 19) / 20);

            if (TCRemaining >= nextWeeklyFee) {
                TCRemaining -= nextWeeklyFee;
                weeklyUserUpkeep = nextWeeklyFee;
                daysRemaining += 7;
            }
            else {
                uint nextDailyFee = (weeklyUserUpkeep + (uint((weeklyUserUpkeep + 19) / 20))) / 7;

                if (TCRemaining >= nextDailyFee) {
                    for (uint x; x < 7; x++) {
                        if (TCRemaining >= nextDailyFee) {
                            TCRemaining -= nextDailyFee;
                            daysRemaining += 1;
                        }
                        else {
                            break;
                        }
                    }
                }
                
                break;
            }
        }
        return daysRemaining;
    }

    // getUser()
    //     |-- address:    adresse                      what wallet address is being inquired about?
    //     |-- address:    from                         which BotPool fulfilled this `getInfo()` request?
    //     |-- bool:       isRegistered                 has this user ever deposited into BotPool?
    //     |-- bool:       isBadUser                    is this user pending removal from BotPool for failing the Weekly Fee?
    //     |-- uint8:      pendingWithdrawAll           is the user requesting to withdraw everything upon trade exit? 0 = no | 1 = cash only | 2 = cash + tokens
    //     |-- uint:       userID                       `userID` number assigned in BotPool
    //     |-- uint:       inBotSince                   number of seconds this user has been in the Bot
    //     |-- uint:       pctOneHundred                number by which all over variables prefixed with `pct` must be divided
    //     \\-- group: botTrader
    //         |-- address:    membership               address of the BotTrader to which the user is assigned
    //         |-- uint:       userID                   `userID` number assigned to this user inside this BotTrader    
    //         |-- uint:       pctOwnership             percentage of the BotTrader balance owned by this user
    //         |-- int:        tradeStatus              `tradeStatus` from the BotTrader assigned to this user
    //     \\-- group: upkeep
    //         |-- uint:       timeNext                 == BotPool.nextTimeUpkeep(userID)
    //         |-- uint:       timeLastIncreased        == BotController.lastTimeUpkeepModified()
    //         |-- uint:       fee                      == BotController.tcFeeOf(account)
    //         |-- uint:       minWeeks                 == BotController.minFutureWeeksTCDeposit()
    //         |-- uint:       reqFromZeroCash          amount of `tc` required to pay for the remainder of the week if coming from zero `cash` balance
    //         |-- uint:       cumulative               == BotPool.cumulativeTCUpkeep(userID)
    //         |-- uint:       daysRemaining            number of days remaining if the above `fee` does not change
    //     \\-- group: cash
    //         |-- uint:       balance                  `total` - `fee`
    //         |-- uint:       deposited                initial balance
    //         |-- uint:       total                    == BotTrader.getBalanceOf
    //         |-- uint:       profit                   amount the user has made, subject to net-profit fee
    //         |-- uint:       fee                      net-profit fee owed
    //         |-- int:        pnl                      `balance` - `deposited`
    //         \\-- group: activeTrade
    //             |-- uint:       startingBalance      initial balance at the start of the current trade
    //             |-- uint:       profit               amount they've made since the start of the current trade, subject to fee
    //             |-- uint:       fee                  net-profit fee owed
    //             |-- int:        pnl                  `balance` - `deposited`
    //         \\-- group: pending
    //             |-- uint:       deposit              amount of cash waiting to be deposited upon trade exit
    //             |-- uint:       withdrawal           amount of cash waiting to be withdrawn upon trade exit   
    //             |-- bool:       withdrawAll          is the user requesting to withdraw all cash upon trade exit?
    //         \\-- group: withdraw
    //             |-- uint:       max                  `balance`, i.e maximum amount withdrawable pending or if the Bot is not in a trade
    //             |-- uint:       fee                  fee owed if submitting a `Withdraw All Now` request
    //         |-- uint:       minReqBalance            minimum required cash to be on-deposit
    //         |-- uint:       allowance                amount of `cash` BotPool is permitted to TransferFrom()
    //     \\-- group: tc
    //         |-- uint:       balance                  amount of this user's TC in BotPool
    //         |-- uint:       operatingDeposit         == BotPool.operatingDeposit(userID)
    //         |-- uint:       vested                   amount of TC this user still has locked under vesting in BotPool
    //         |-- uint:       vestedStartDate          UNIX timestamp in seconds from 1970 of when vesting started; uses Global first and User-specific fallback
    //         |-- uint:       vestedEndDate            UNIX timestamp in seconds from 1970 of when vesting shall end; uses Global first and User-specific fallback
    //         \\-- group: pending
    //             |-- uint:       withdrawal           amount of TC to withdraw upon trade exit
    //             |-- bool:       withdrawAll          is the user requesting to withdraw their entire TC balance from BotPool upon trade exit?
    //         \\-- group: withdraw
    //             |-- uint:       max                  maximum amount of TC that can be withdrawn, taking into account the Operating Deposit and `minReqBalanceTC`
    //         |-- uint:       minReqBalance            minimum required TC to be on-deposit
    //         |-- uint:       allowance                amount of `tc` BotPool is permitted to TransferFrom()
    //     \\-- group: tcc
    //         |-- uint:       balance                  amount of this user's TCC in BotPool
    //         |-- uint:       pctMultiplier            what multiplier does this user receive based on their NFT level?
    //         |-- uint:       pctApr                   percentage of tcc based on tc (ex. 42% means 42 TCC in 1 year if 100 TC is on-deposit)
    //         |-- uint:       rewardPerWeek            amount of `tcc` this user can expect to receive this week
    //         |-- uint:       lastTimeRewarded         UNIX timestamp in seconds from 1970 of when `tcc` rewards was last calculated
    //     \\-- group: nft
    //         |-- uint:       level                    what is this user's highest NFT level?
    //         |-- uint[]:     levelBalances            number of each NFT level this user owns
    //         |-- NFTs[]:     ownedList                list of all NFTs this user owns
    //         |-- uint:       pctFeeReduction          what percentage reduction in fees does this user receive, based on their `level` above?

    // BotPool then User to keep the same order as `getInfo()`
    function getUser(address botPool, address account) external view returns (GetUserStruct memory _user) {
        _user = setupUserObj(botPool, account);

        if (!_user.isRegistered) {
            _user.adresse = msg.sender;
            return _user;
        }

        IBotPool BotPool = IBotPool(botPool);
        IBotController BotController = BotPool.botController();
        IBotTrader BotTrader = BotPool.inBotTrader(_user.userID);
        _user.botTrader.membership = address(BotTrader);
        _user.botTrader.userID = BotTrader.userIDs(account);

        BotTraderReturns memory __user = getBotTraderUser(BotTrader, _user.botTrader.userID);
        uint[valuesLength] memory values = BotTrader.getWithdrawEstimates(account, _user.botTrader.userID, type(uint).max, true);

        _user.cash.withdraw.max                 = values[0];
        _user.cash.withdraw.fee                 = values[1] + values[2];
        _user.cash.total                        = __user.total;
        _user.cash.deposited                    = __user.deposited;
        _user.cash.balance                      = _user.cash.total;
        _user.cash.fee                          = __user.fee;
        _user.cash.pnl                          = __user.profit - int(__user.fee);
        _user.cash.activeTrade.startingBalance  = __user.activeTradeStartingBalance;
        _user.cash.pending.deposit              = __user.pendingDeposit;
        _user.cash.pending.withdrawal           = __user.pendingWithdrawal;
        _user.cash.pending.withdrawAll          = __user.pendingWithdrawAll != 0;
        _user.cash.minReqBalance                = BotController.minReqBalCash();
        _user.pendingWithdrawAll                = __user.pendingWithdrawAll;
        _user.tc.pending.withdrawAll            = __user.pendingWithdrawAll == 2;

        if (_user.cash.pnl > 0) {
            _user.cash.profit = uint(__user.profit); // excludes fees; includes losses)
        }

        uint _profitFee = BotController.pctProfitFeeOf(account);
        uint totalCashBalance = BotTrader.getBotTotalCashBalance();

        // Calculate the `pctOwnership` before adjusting the numbers
        // with the Frontend's offset `pctCashPnL`.
        _user.botTrader.pctOwnership = 
            totalCashBalance > 0
            ? _user.pctOneHundred * _user.cash.balance / totalCashBalance
            : 0;

        _user.botTrader.tradeStatus = BotTrader.tradeStatus();
        if (_user.botTrader.tradeStatus != 0) {
            IFrontend Frontend = IFrontend(BotController.frontend());
            uint _pctCashPnL =
                Frontend.pctCashPnL(
                    _user.botTrader.tradeStatus == -1
                    ? 1 : 0
                ); // minBalQualifyPct();
            uint _pctOneHundred = Frontend.pctOneHundred();
            _user.cash.withdraw.max *= _pctCashPnL;
            _user.cash.withdraw.fee *= _pctCashPnL;
            _user.cash.total        *= _pctCashPnL;
            _user.cash.withdraw.max /= _pctOneHundred;
            _user.cash.withdraw.fee /= _pctOneHundred;
            _user.cash.total        /= _pctOneHundred;

            _user.cash.activeTrade.pnl = int(_user.cash.total) - int(_user.cash.activeTrade.startingBalance);
            _user.cash.pnl += _user.cash.activeTrade.pnl;

            if (_user.cash.activeTrade.pnl > 0) {
                _user.cash.activeTrade.profit = uint(_user.cash.activeTrade.pnl); // excludes fees; includes losses
                _user.cash.profit += _user.cash.activeTrade.profit; // excludes fees; includes losses

                _user.cash.activeTrade.fee = _user.cash.activeTrade.profit * _profitFee / _user.pctOneHundred;
                _user.cash.fee += _user.cash.activeTrade.fee;
                
                _user.cash.activeTrade.pnl -= int(_user.cash.activeTrade.fee);
                _user.cash.pnl -= int(_user.cash.activeTrade.fee);

                if (_user.cash.balance > _user.cash.activeTrade.fee) {
                    _user.cash.balance -=  _user.cash.activeTrade.fee;
                }
            }
        }

        return _getUserStackTooDeepHelper(account, BotPool, BotController, _user);
    }

    function _getUserStackTooDeepHelper(
        address account,
        IBotPool BotPool,
        IBotController BotController,
        GetUserStruct memory _user
    ) private view returns (GetUserStruct memory) {
        // _user.tc.operatingDeposit = 
        if (_user.cash.total > 0) {
            if (_user.tc.total < _user.tc.operatingDeposit) {
                delete _user.upkeep.daysRemaining;
                delete _user.tc.balance;
            }
            else {
                _user.tc.balance = _user.tc.total - _user.tc.operatingDeposit; // - BotController.minReqBalTC();

                if (_user.upkeep.fee > 0) {
                    _user.upkeep.daysRemaining = _calcDaysRemaining(
                        address(BotPool),
                        _user.upkeep.fee,
                        (_user.tc.balance / _user.upkeep.fee) + 1,
                        _user.tc.balance,
                        0 // BotController.maxSingleLoopSize()
                    );
                }
            }
        }
        else if (_user.tc.balance > 0) {
            _user.upkeep.daysRemaining = type(uint).max;
        }

        if (_user.tc.balance > _user.tc.minReqBalance + _user.tc.vested.total) {
            _user.tc.withdraw.max = _user.tc.balance - (_user.tc.minReqBalance + _user.tc.vested.total);
        }

        _user.tcc.pctApr = BotController.pctRewardRateOf(account, _user.cash.balance > 0);
        _user.tcc.pctMultiplier = _user.tcc.pctApr / BotController.apr();

        if (block.timestamp > _user.tcc.lastTimeRewarded) {
            _user.tcc.balance += BotController.tccRewardCalcOf(
                account,
                _user.cash.total > 0,
                int(block.timestamp) - int(_user.tcc.lastTimeRewarded),
                _user.tc.balance
            );
        }

        _user.tcc.rewardPerWeek = 
            BotController.tccRewardCalcOf(
                account,
                _user.cash.balance > 0,
                int(BotController.secPerWeek()),
                _user.tc.balance
            );



        // (‿ˠ‿) 


        return _user;
    }

    function getBotTraderUser(
        IBotTrader BotTrader,
        uint userID
    ) public view returns (BotTraderReturns memory user) {
        

        // (‿ˠ‿) 

        
        user.total = BotTrader.getBalanceOfUserID(userID);
        user.deposited = BotTrader.deposited(userID);
        user.profit = BotTrader.totalChange(userID);
        user.fee = BotTrader.totalFeePaid(userID);
        user.activeTradeStartingBalance = BotTrader.balanceTradeStart(userID);
        user.pendingDeposit = BotTrader.pendingDeposit(userID);
        user.pendingWithdrawal = BotTrader.pendingWithdrawal(userID);
        user.pendingWithdrawAll = BotTrader.withdrawAllType(userID);

        return user;
    }

    function setupUserObj(address botPool, address account) private view returns (GetUserStruct memory _user) {
        IBotPool BotPool = IBotPool(botPool);
        IBotController BotController = BotPool.botController();
        INFTAdmin NFTAdmin = BotController.nftAdmin();

        uint userID = BotPool.userIDs(account);
        uint oneHundredPct = BotPool.oneHundredPct();

        _user = GetUserStruct(
            BotPool.userAddress(userID),
            botPool,
            BotPool.isRegistered(userID),
            BotPool.isBadUser(userID),
            0, // set in Frontend
            userID,
            BotPool.secsInBot(userID) + (BotPool.inBotSince(userID) > 0 ? block.timestamp - BotPool.inBotSince(userID) : 0),
            oneHundredPct,
            BotTraderStruct( // all are set in Frontend
                address(0),
                0,
                0,
                0
            ),
            Upkeep(
                0, // stack too deep -- BotPool.nextTimeUpkeep(userID),
                BotController.lastTimeUpkeepModified(),
                0, // stack too deep -- BotController.tcFeeOf(account),
                BotController.minFutureWeeksTCDeposit(),
                0,
                0, // stack too deep -- BotPool.cumulativeTCUpkeep(userID),
                0
            ),
            Cash( // all are set in Frontend
                0,
                0,
                0,
                0,
                0,
                0,
                ActiveTrade(
                    0,
                    0,
                    0,
                    0
                ),
                Pending(
                    0,
                    0,
                    false
                ),
                Withdraw(
                    0,
                    0
                ),
                BotController.minReqBalCash(),
                0 // stack too deep; set above in parent function :: IERC20(BotPool.cash()).allowance(account, botPool)
            ),
            TC(
                BotPool.balanceTC(userID),
                BotPool.balanceTC(userID),
                BotPool.operatingDepositTC(userID),
                Vested(
                    false,
                    0,
                    0,
                    0,
                    VestedAmount(
                        0,
                        0
                    ),
                    VestedAmount(
                        0,
                        0
                    ),
                    VestedAmount(
                        0,
                        0
                    ),
                    VestedAmount(
                        0,
                        0
                    )
                ),
                PendingTC(
                    BotPool.pendingWithdrawalTC(userID),
                    false // set in Frontend
                ),
                WithdrawTC(
                    0 // set in Frontend
                ),
                0, // stack too deep -- BotController.minReqBalTC() + BotPool.operatingDepositTC(userID) + oneYearVestedTC + threeYearVestedTC, // duplicate in BotPoolLib
                0  // stack too deep; set above in parent function :: IERC20(BotPool.tc()).allowance(account, botPool)
            ),
            TCC(
                BotPool.balanceTCC(userID),
                0, // multiplier | set in Frontend
                0, // apr | set in Frontend
                0, // rewards per week | set in Frontend
                BotPool.lastTimeRewarded(userID)
            ),
            NFT(
                NFTAdmin.highestLevelOf(account),
                // NFTAdmin.levelBalancesOf(account),
                // NFTAdmin.nftsOf(account),
                BotController.pctFeeReductionOf(account)
            )
        );

        uint nextTimeUpkeepGlobal = BotPool.nextTimeUpkeepGlobal();

        _user.upkeep.reqFromZeroCash =
            BotController.tcReqUpkeepPaymentOf(
                account,
                int(
                    _user.upkeep.timeNext > nextTimeUpkeepGlobal - BotController.weeklyFeeTimeSlippage() ?
                    _user.upkeep.timeNext : nextTimeUpkeepGlobal
                ) - int(block.timestamp)
            );

        return _getUserStackTooDeepHelper2(BotPool, BotController, account, userID, _user);
    }

    function _getUserStackTooDeepHelper2(IBotPool BotPool, IBotController BotController, address account, uint userID, GetUserStruct memory _user) private view returns (GetUserStruct memory) {
        _user.upkeep.fee = BotController.tcFeeOf(account);
        _user.upkeep.cumulative = BotPool.cumulativeTCUpkeep(userID);
        _user.upkeep.timeNext = BotPool.nextTimeUpkeep(userID);

        // uint oneYearTC = BotPool.remainingVestedTCOfID(userID, 1);
        // uint twoYearsTC = BotPool.remainingVestedTCOfID(userID, 2);
        // uint threeYearsTC = BotPool.remainingVestedTCOfID(userID, 3);
        // uint fourYearsTC = BotPool.remainingVestedTCOfID(userID, 4);
        // uint totalUserVestedTC = oneYearTC + twoYearsTC + threeYearsTC + fourYearsTC;
 
        _user.tc.vested = getVestedOfUserID(BotPool, userID);

        _user.tc.minReqBalance = BotController.minReqBalTC() + BotPool.operatingDepositTC(userID) + _user.tc.vested.total;
        
        _user.tc.allowance = IERC20(BotPool.tc()).allowance(account, address(BotPool));
        _user.cash.allowance = IERC20(BotPool.cash()).allowance(account, address(BotPool));
        
        return _user;
    }

    function getVestedOf(address botPool, address account) external view returns (Vested memory) {
        IBotPool BotPool = IBotPool(botPool);
        return getVestedOfUserID(BotPool, BotPool.userIDs(account));
    }

    function getVestedOfUserID(IBotPool BotPool, uint userID) public view returns (Vested memory) {
        uint oneYearTC = BotPool.remainingVestedTCOfID(userID, 1);
        uint twoYearsTC = BotPool.remainingVestedTCOfID(userID, 2);
        uint threeYearsTC = BotPool.remainingVestedTCOfID(userID, 3);
        uint fourYearsTC = BotPool.remainingVestedTCOfID(userID, 4);
        uint totalUserVestedTC = oneYearTC + twoYearsTC + threeYearsTC + fourYearsTC;
 
        return
            Vested(
                BotPool.vestingFrozen(),
                totalUserVestedTC,
                BotPool.vested(0, 0),
                BotPool.vested(userID, 0),
                VestedAmount(
                    oneYearTC,
                    BotPool.vested(0, 1)
                ),
                VestedAmount(
                    twoYearsTC,
                    BotPool.vested(0, 2)
                ),
                VestedAmount(
                    threeYearsTC,
                    BotPool.vested(0, 3)
                ),
                VestedAmount(
                    fourYearsTC,
                    BotPool.vested(0, 4)
                )
            );
    }

}