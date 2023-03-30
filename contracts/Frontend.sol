// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./libraries/Caffeinated.sol";
import "./libraries/FrontendLib_getInfo.sol";
import "./libraries/FrontendLib_getUser.sol";
import "./libraries/FrontendLib_getInfoAdmins.sol";
import "./libraries/FrontendLib_vestedTC.sol";
import "./libraries/FrontendLib_depositWithdraw.sol";
import "./libraries/BotTraderLib_withdraw.sol";
import "./libraries/BotControllerLib_structs.sol";

import "./interfaces/IBotController.sol";
import "./interfaces/IBotPool.sol";
import "./interfaces/IBotTrader.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC20T.sol";

// import "hardhat/console.sol";

contract Frontend {

    

    // ------ STORAGE ------
    string public constant version = "2023-01-31 | Alpha v2";

    address public botController;
    IBotController public BotController;

    uint public constant pctOneHundred = Caffeinated.precision;
    uint[2] public pctCashPnL;

    constructor(uint[2] memory _pctCashPnL) {
        _setBotController(msg.sender);
        pctCashPnL = _pctCashPnL;
    }

    function editorLevel(address sender) public view returns (bool) {
        return sender == botController || BotController.getIsEditor(sender) || sender == BotController.adminWallet();
    }

    modifier _editorAuth() {
        require(
            editorLevel(msg.sender),
            "FRONTEND | AUTH: Only an Editor, the Admin Wallet, or BotController."
        );
        _;
    }

    function _setBotController(address _newBotController) private {
        botController = _newBotController;
        BotController = IBotController(botController);
    }

    function setBotController(address _newBotController) external _editorAuth() {
        require(
            msg.sender == botController
            || BotController.frontend() == address(this),
            "FRONTEND | SET BOT CONTROLLER: Not linked to this Frontend."
        );
        _setBotController(_newBotController);
    }

    function setPctCashPnL(uint[2] calldata _pctCashPnL) external _editorAuth() {
        uint _pctTenHundred = pctOneHundred * 10;
        for (uint8 i; i < _pctCashPnL.length; ++i) {
            require(_pctCashPnL[i] < _pctTenHundred, "FRONTEND | SET PCT CASH PNL: Cannot be 10x 100% or larger.");
        }
        pctCashPnL = _pctCashPnL;
    }
    // ---- end storage ----


    
    // ### GETTER FUNCTIONS ###
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
    //         \\-- group: cumulative
    //             |-- int:        profit               running total of all past profit
    //             |-- uint:       fee                  running total of all net-profit fees charged
    //             |-- int:        pnl                  running total of all net-profit (estimated)
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
    function getUser(address botPool) external view returns (FrontendLib_getUser.GetUserStruct memory user) {
        return FrontendLib_getUser.getUser(botPool, msg.sender);
    }

    function getUserOf(address botPool, address account) external view returns (FrontendLib_getUser.GetUserStruct memory user) {
        return FrontendLib_getUser.getUser(botPool, account);
    }

    // getInfo()
    //     |-- address:    from                         which BotPool fulfilled this `getInfo()` request?
    //     |-- string:     mode                         example: "Automatic"
    //     |-- string:     timeframe                    timeframe of the chart for the strategy being applied in this BotPool
    //     |-- string:     strategyName                 name of the strategy being applied in this BotPool
    //     |-- string:     description                  general description and notepad for this BotPool
    //     |-- uint:       totalBotBalanceCash;         the sum of all value held by BotTraders in this BotPool as measured in `cash`
    //     |-- uint:       totalBotDebtCash;            the sum of all debt held by BotTraders in this BotPool as measured in `cash`
    //     |-- uint:       entryPrice                   entry price from the first active BotTrader from `botTraders --> list`
    //     |-- uint:       entryPriceDecimals           decimals of the above `entryPrice`; denominator is 10 ^ {{ this }}
    //     \\-- group: botTraders
    //         |-- address[]:  list                     list of all BotTraders in this BotPool (BotTraders are children of BotPools)
    //         |-- uint:       count                    how many BotTraders are there in this BotPool?
    //         |-- uint:       max                      what's the maximum number of permitted BotTraders for this BotPool?
    //         |-- address:    available                which BotTrader is currently accepting users?
    //         |-- address:    botFactory               address of the BotFactory from which BotTraders are created
    //     \\-- group: upkeep
    //         |-- uint:   nextTime                 timestamp given in UNIX time of seconds when the weekly upkeep fee will next be charged
    //         |-- uint:   lastTimeModified         timestamp given in UNIX time of seconds when the weekly upkeep fee was last modified
    //         |-- uint:   fee                      amount of `tc` to be charged at the next weekly upkeep
    //         |-- uint:   minWeeks                 number of weeks of {{ n Σ `fee` + 5% }} required
    //         |-- uint:   reqFromZeroCash          amount of `tc` to be charged from present `block.timestamp` to the next weekly upkeep
    //     \\-- group: asset
    //         |-- address:    adresse                  address of the token to trade against AKA `asset`
    //         |-- string:     symbol                   ticker/symbol of the `asset` token
    //         |-- uint8:      decimals                 number of decimals this currency has; denominator is 10 ^ {{ this }}
    //         |-- uint:       denominator              10 ** `decimals` above
    //     \\-- group: cash
    //         |-- address:    adresse                  address of the token users deposit AKA `cash`
    //         |-- string:     symbol                   ticker/symbol of the `cash` token
    //         |-- uint8:      decimals                 number of decimals this currency has; denominator is 10 ^ {{ this }}
    //         |-- uint:       denominator              10 ** `decimals` above
    //         |-- uint:       balance                  total amount of `cash` for the BotPool; running internal total NOT cash.balanceOf(address(BotPool))
    //         |-- uint:       botPoolMax               if BotPool has more than this amount of `cash`, Deposits will be suspended
    //         |-- uint:       perUserMax               if a user has more than this amount of `cash`, they will be unable to Deposit more
    //         |-- uint:       overSwapMax              when performing a swap to withdraw immediately, this is the `cash` limit to overswap beyond the requested amount
    //         |-- uint:       minReqBalance            threshold of `cash` below which users are unable to partially withdraw
    //     \\-- group: tc
    //         |-- address:    adresse                  address of the token users deposit AKA `tc`
    //         |-- string:     symbol                   ticker/symbol of the `tc` token
    //         |-- uint8:      decimals                 number of decimals this currency has; denominator is 10 ^ {{ this }}
    //         |-- uint:       denominator              10 ** `decimals` above
    //         |-- uint:       balance                  total amount of TC for the BotPool; running internal total NOT tc.balanceOf(address(BotPool))
    //         |-- address:    adminWallet              expected to be the same multi-sig wallet as `addresses --> adminWallet`
    //         |-- address:    treasuryWallet           expected to be the same multi-sig wallet as `addresses --> treasuryWallet`
    //         |-- uint:       circulatingSupply        amount of `tc` not held by the admin or treasury wallets
    //         |-- uint:       operatingDepositRatio    amount of `tc` per `cash` that must be deposited
    //         |-- uint:       minReqBalance            minimum required amount of `tc` to be held on-deposit
    //     \\-- group: tcc
    //         |-- address:    adresse                  address of the token users deposit AKA `tcc`
    //         |-- string:     symbol                   ticker/symbol of the `tcc` token
    //         |-- uint8:      decimals                 number of decimals this currency has; denominator is 10 ^ {{ this }}
    //         |-- uint:       denominator              10 ** `decimals` above
    //         |-- uint:       balance                  total amount of TCC for the BotPool; IS == tcc.balanceOf(address(BotPool))
    //         |-- address:    adminWallet              expected to be the same multi-sig wallet as `addresses --> adminWallet`
    //         |-- address:    treasuryWallet           expected to be the same multi-sig wallet as `addresses --> treasuryWallet`
    //         |-- uint:       circulatingSupply        amount of `tcc` not held by the admin or treasury wallets
    //         \\-- group: rewards
    //             |-- uint:   nextUser                 == BotPool.tccNextUserToReward()
    //             |-- uint:   inEscrow                 == botPool.tccInEscrow()
    //             |-- uint:   timeFrozen               == BotPool.tccTimeFrozen()
    //             |-- uint:   timeToMelt               == BotPool.tccTimeToMelt()
    //             |-- uint:   timeEnabled              == BotPool.tccTimeEnabled()
    //     \\-- group: pct
    //         |-- uint:       oneHundred               number representing 100.0%; divisor for all below values inside this `pct` group
    //         |-- uint:       profitFee                percentage of profits sent to the `treasuryWallet` upon standard, pending withdrawal
    //         |-- uint:       profitFeePenalty         percentage of profits sent to the `treasuryWallet` when immediately withdrawn
    //         |-- uint:       apr                      percentage of `tcc` earned for `tc` deposited; 1000 TC @ 21.0% `apr` = 210 TCC earned in 1 year
    //         |-- uint:       aprBotBonus              percentage of `tcc` earned for `cash` deposited
    //         |-- uint:       slippage                 maximum amount of frontrunning price movement acceptable when swapping
    //         |-- uint:       reserve                  percentage of `cash` held outside of AAVE when in a Short position
    //         |-- uint:       borrow                   percentage of `cash` to borrow in `asset` value; 68% 1000 `cash` = $680 worth of Bitcoin @ $50/BTC = 13.6 BTC borrowed
    //         |-- uint:       dexFee                   maximum amount of liquidity provider fee acceptable when swapping
    //         |-- uint:       overSwap                 maximum percentage of a withdrawing position acceptable to overswap; 5 `cash` request = 0.15 `cash` max overswap
    //         |-- uint:       minBalQuality            minimum amount of `cash` a user must receive for a Withdraw All transaction to succeed
    //         |-- uint:       shortSlippage            approximation of slippage fees when Short; attempts to charge slippage to the withdrawing user
    //         |-- uint[]:     feeReductions            list of percentage fee reductions applied when owning an NFT; in ascending order
    //     \\-- group: adresse     
    //         |-- address:    frontend                 intended to be the same as this contract AKA `address(this)`
    //         |-- address:    botController            from where BotPool gets its values; has authority over BotPool parameters
    //         |-- address:    adminWallet              intended to be the same as the TC Main multi-sig wallet
    //         |-- address:    treasuryWallet           intended to be the same as the TC Treasury multi-sig wallet
    //         |-- address:    weeklyFeeWallet          set and managed by the editors such as Trendespresso
    //         |-- address:    nftAdmin                 smart contract administering all NFTs in use by BotPool
    //         |-- address:    presale                  the Presale smart contract address
    //         |-- address:    originalFrontend         taken from BotPool; immutable after deployment
    //         |-- address[]:  originalContracts        a list of contracts at deployment time
    //     \\-- group: sys
    //         |-- bool:       contractIsFrozen         == BotPool.contractIsFrozen()
    //         |-- uint:       presaleTimeEnded         == BotPool.presaleTimeEnded()
    //         |-- uint:       vestingEndTimeGlobal     == BotPool.vestingEndTimeGlobal()
    //         |-- uint:       minGas                   == BotPool.minGas()
    //         |-- uint:       numUsers                 == BotPool.numUsers()
    //         |-- uint:       maxUsers                 == BotPool.maxUsers()
    //         |-- uint:       timeLastModifiedProfitFee == BotController.
    //         |-- uint:       maxSingleLoopSize        maximum number of items that can be looped in a single transaction of ≈ 8m gas
    //         |-- uint:       maxPendingTX             maximum number of pending Editor multi-sig transactions that can co-exist

    function getInfo(address botPool) external view returns (FrontendLib_getInfo.Info memory info) {
        return FrontendLib_getInfo.getInfo(botPool);
    }

    function getBotTraderObject(address botPool) external view returns (FrontendLib_getInfo.BotTradersAdmins memory botTraderAdmins) {
        return FrontendLib_getInfo.getBotTraderObject(botPool, msg.sender);
    }

    




    // ### WITHDRAW AMOUNTS FUNCTIONS ###
    function getWithdrawEstimates(
        address botPool,
        uint amountTC,
        uint amountCash,
        bool withdrawNow_
    ) external view returns (FrontendLib_depositWithdraw.WithdrawEstimates memory withdrawEstimates) {
        return getWithdrawEstimatesOf(botPool, msg.sender, amountTC, amountCash, withdrawNow_);
    }

    function getWithdrawEstimatesOf(
        address botPool,
        address account,
        uint amountTC,
        uint amountCash,
        bool withdrawNow_
    ) public view returns (FrontendLib_depositWithdraw.WithdrawEstimates memory withdrawEstimates) {
        return FrontendLib_depositWithdraw.getWithdrawEstimatesOf(botPool, account, amountTC, amountCash, withdrawNow_);
    }

    // function getWithdrawEstimatesTrader(
    //     address BotTrader,
    //     uint BotTraderUserID,
    //     uint amountCash,
    //     bool immediateWithdrawal
    // ) external view returns (WithdrawEstimates memory withdrawEstimates) {
    //     return _getWithdrawEstimates(msg.sender, IBotTrader(BotTrader), BotTraderUserID, amountCash, immediateWithdrawal);
    // }

    // function getWithdrawEstimatesWeeklyFee(
    //     address BotPool,
    //     address account,
    //     uint userID
    // ) external view returns (WithdrawEstimates memory withdrawEstimates) {
    //     IBotTrader BotTrader = IBotPool(BotPool).inBotTrader(userID);

    //     return _getWithdrawEstimates(account, BotTrader, BotTrader.userIDs(account), 0, BotTrader.tradeStatus() != 0);
    // }

    // function _getWithdrawEstimates(
    //     address account,
    //     IBotTrader BotTrader,
    //     uint BotTraderUserID,
    //     uint amountCash,
    //     bool immediateWithdrawal
    // ) private view returns (WithdrawEstimates memory withdrawEstimates) {
    //     uint[] memory amounts = BotTrader.getWithdrawEstimates(account, BotTraderUserID, amountCash, immediateWithdrawal);

    //     return _wrapWithdrawEstimates(amounts);
    // }




    // ### DEPOSIT AMOUNTS FUNCTIONS ###
    // For use concurrently with some amount of cash deposit

    function getDepositEstimates(
        address botPool,
        uint amountTC,
        uint amountCash
    ) external view returns (FrontendLib_depositWithdraw.DepositEstimates memory depositEstimates) {
        return getDepositEstimatesOf(botPool, msg.sender, amountTC, amountCash);
    }

    function getDepositEstimatesOf(
        address botPool,
        address account,
        uint amountTC,
        uint amountCash
    ) public view returns (FrontendLib_depositWithdraw.DepositEstimates memory depositEstimates) {
        return FrontendLib_depositWithdraw.getDepositEstimatesOf(botPool, account, amountTC, amountCash);
    }

    // _calcDaysRemaining(
    //                 BotController.tcFeeOf(account);,
    //                 ((amountTC - operatingDeposit) / BotController.tcFeeOf(account)) + 1,
    //                 amountTC - operatingDeposit,
    //                 0 // BotController.maxSingleLoopSize()
    //             );

    //  function tcReqDepositOf(address account, uint amountCash, int time) external view returns (uint) {
    //     return minReqBalTC() + tcReqUpkeepPaymentOf(account, time) + tcReqOperatingDepositOf(account, amountCash);
    // }


    // function getDepositAmounts(
    //     address BotTrader,
    //     uint BotTraderUserID,
    //     uint amountCash
    // ) external view returns (uint) {
    //     return _getReqTCDeposit(msg.sender, IBotTrader(BotTrader), BotTraderUserID, amountCash);
    // }

    // function _getReqTCDeposit(
    //     address account,
    //     IBotTrader BotTrader,
    //     uint BotTraderUserID,
    //     uint amountCash
    // ) private view returns (uint) {
    //     return IBotController(BotTrader.botController()).tcReqDepositOf(
    //         account,
    //         amountCash,
    //         int(
    //             BotTrader.hasBalanceUserID(BotTraderUserID) ?
    //                 int(0)
    //             :
    //                 int(IBotPool(BotTrader.botPool()).nextTimeUpkeepGlobal()) - int(block.timestamp)
    //         )
    //     );
    // }




    // ### TRADE GETTER FUNCTIONS ###
    // Maybe we don't need to lock down these values? Does it present a security risk or nah?

    // All are the amount to SELL, except Short Exit which is amount to BUY.
    // Cash for Long Entry; Asset for all others.
    function cashBalanceOf(address botTrader) public view returns (uint) {
        return IBotTrader(botTrader).cash().balanceOf(botTrader);
    }

    function assetBalanceOf(address botTrader) public view returns (uint) {
        return IBotTrader(botTrader).asset().balanceOf(botTrader);
    }

    function longEntry_sellCash(address botTrader) external view returns (uint) {
        return cashBalanceOf(botTrader);
    }

    function longExit_sellAsset(address botTrader) external view returns (uint) {
        return assetBalanceOf(botTrader);
    }

    function shortEntry_sellAsset(address botTrader) external view returns (uint) {
        // The amount to borrow should be available when the shortEntry()
        // is executed since that's the time at which the BotTrader will
        // deposit into AAVE and have borrowed BTC.b.
        return IBotTrader(botTrader).shortEntry_getAmountToBorrow();
    }

    function shortExit_buyAsset(address botTrader) external view returns (uint) {
        return IBotTrader(botTrader).getAssetDebt();
    }

    function getTradeStatusOf(address botTrader) external view returns (int) {
        return IBotTrader(botTrader).getTradeStatusOf(msg.sender);
        // Works for inputting either BotPool or BotTrader.
        // If BotTrader, will return *that* BotTrader's tradeStatus
        // or if BotPool, will return the msg.sender's BotTrader's tradeStatus.
    }

    function getBotTotalCashBalance(address botTrader) external view returns (uint) {
        return IBotTrader(botTrader).getBotTotalCashBalance();
    }




    // ### DEPOSIT FUNCTIONS ###
    // TC and/or cash
    // Pending during a trade
    function deposit(address botPool, uint amountTC, uint amountCash) external {
        IBotPool(botPool).deposit(msg.sender, amountTC, amountCash, 0, 0, 0, bytes32(0), bytes32(0));
    }
    // function deposit(address sender, uint amountTC, uint amountCash, uint tcToApprove, uint deadline, uint8 v, bytes32 r, bytes32 s)
    function depositWithPermit(address botPool, uint amountTC, uint amountCash, uint tcToApprove, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        IBotPool(botPool).deposit(msg.sender, amountTC, amountCash, tcToApprove, deadline, v, r, s);
    }




    // ### WITHDRAW FUNCTIONS ###
    function withdraw(address botPool, uint amountTC, uint amountCash) external {
        IBotPool(botPool).withdraw(msg.sender, amountTC, amountCash);
    }

    // Immediate during a trade
    function withdrawNow(address botPool, uint amountTC, uint amountCash, bytes calldata swapCallData) external {
        IBotPool(botPool).withdrawNow(msg.sender, amountTC, amountCash, swapCallData);
    }




    // ### WITHDRAW ALL FUNCTIONS ###
    // Pending during a trade
    function withdrawAll(address botPool, bool onlyCash) external {
        IBotPool(botPool).withdrawAll(msg.sender, onlyCash);
    }

    // Immediate during a trade
    function withdrawAllNow(address botPool, bool onlyCash, bytes calldata swapCallData) external {
        IBotPool(botPool).withdrawAllNow(msg.sender, onlyCash, swapCallData);
    }




    // ### COLLECT REWARD FUNCTION ###
    function collectRewards(address botPool) external {
        IBotPool(botPool).collectRewards(msg.sender);
    }




    // ### EMERGENCY WITHDRAW ALL FUNCTIONS ###
    // TC and cash
    // Immediate during a trade
    // Will return tokens in addition to/instead of cash token during a trade
    function emergencyWithdrawAllWithDebt(address botPool, uint debtTokens) external {
        IBotPool(botPool).emergencyWithdrawAll(msg.sender, debtTokens);
    }

    function emergencyWithdrawAll(address botPool) external {
        IBotPool(botPool).emergencyWithdrawAll(msg.sender, 0);
    }




    // ### CANCEL PENDING FUNCTIONS ###
    function cancelPendingTransfers(address botPool) external {
        IBotPool(botPool).cancelPendingTransfers(msg.sender);
    }




    // ### VESTED FUNCTIONS ###
    uint8 public constant t = 5; // MUST == BotPool.t()

    function checkVestedTC_vs_newBotPool(address botPool, address newBotPool) external view returns (bool, uint) {
        return FrontendLib_vestedTC.checkVestedTC_vs_newBotPool(botPool, newBotPool);
    }

    function checkVestedTC_vs_unnamedArrays(address botPool, address[] calldata userAddress, uint[t][] calldata vested) external view returns (bool, uint) {
        return FrontendLib_vestedTC.checkVestedTC_vs_unnamedArrays(botPool, userAddress, vested);
    }

    function getVestedTCUnnamed(address botPool) external view returns (uint[t][] memory) {
        return FrontendLib_vestedTC.getVestedTCUnnamed(botPool);
    }

    function getUserAddresses(address botPool) external view returns (address[] memory) {
        return FrontendLib_vestedTC.getUserAddresses(botPool);
    }

    function getVestingHashFromUnnamed(address botPool, address[] calldata userAddress, uint[t][] calldata vested) external view returns (bytes32) {
        return FrontendLib_vestedTC.getVestingHashFromUnnamed(botPool, userAddress, vested);
    }

    function checkVestedTC_vs_namedArray(address botPool, FrontendLib_vestedTC.Vested[] calldata vestedObj) external view returns (bool, uint) {
        return FrontendLib_vestedTC.checkVestedTC_vs_namedArray(botPool, vestedObj);
    }

    function getVestedTCNamed(address botPool) external view returns (FrontendLib_vestedTC.Vested[] memory) {
        return FrontendLib_vestedTC.getVestedTCNamed(botPool);
    }

    function getVestingHashFromNamed(address botPool, FrontendLib_vestedTC.Vested[] calldata vestedObj) external view returns (bytes32) {
        return FrontendLib_vestedTC.getVestingHashFromNamed(botPool, vestedObj);
    }




    // ### UTILITY FUNCTIONS ###
    // Allows anyone to withdraw tokens accidentally sent to this address.
    function claimERC20(address token) external {
        IERC20 _token = IERC20(token);
        _token.transfer(msg.sender, _token.balanceOf(address(this)));
    }

    // Only callable by a team member.
    function getInfoAdmins(address botPool) external view returns (FrontendLib_getInfoAdmins.AdminInfo memory) {
        return FrontendLib_getInfoAdmins.getInfoAdmins(botPool);
    }

}