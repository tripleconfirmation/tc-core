// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "../interfaces/IBotController.sol";
import "../interfaces/IBotPool.sol";
import "../interfaces/IBotTrader.sol";

import "../libraries/Caffeinated.sol";
import "../libraries/FrontendLib_getUser.sol";

// import "hardhat/console.sol";

library FrontendLib_depositWithdraw {

    struct WithdrawEstimates {
        uint pctUserPosition;               // * percentage of the user position they're requesting
        uint cashToReceive;                 // * amount of cash the user will receive
        uint profitFee;                     // * amount of cash the treasury will receive from past trades
        uint penaltyFee;                    // * amount of cash the treasury will receive from current trade
        int currentTradePnL;                // X current trade's profit and loss
        uint totalProfits;                  // X total amount of profits the user is withdrawing
        uint netProfit;                     // X net profit the user will receive
        uint newGuaranteedBotRuntime;       // X guaranteed number of days the bot will run given the new amount of TC after deposit
        uint newCashDeposited;              // * new amount of deposited for the user
        int newCashBalance;                 // X new cash balance of the user -- should never be negative but set as `int` to avoid a revert in case Chainlink estimation is off
        uint tcToReceive;                   // X amount of TC the user will actually receive
        uint newTcTotal;                    // X amount of TC in total
        uint newTcBalance;                  // X amount of TC available for weekly fee payment
        uint newTcVested;                   // X amount of TC still vested
        uint releasedTcOperatingDeposit;    // X amount of TC released
        uint cashToSwap;                    // X == `cashToReceive` + `profitFee` + `penaltyFee`
        uint assetToSwap;                   // * asset needed to be swapped for this withdrawwal request
    }

    // `values` length MUST == BotTraderLib_util.valuesLength
    function _wrapWithdrawEstimates(uint[6] memory values) private pure returns (WithdrawEstimates memory withdrawEstimates) {
        withdrawEstimates.pctUserPosition = values[4];
        withdrawEstimates.cashToReceive = values[0];
        withdrawEstimates.profitFee = values[1];
        withdrawEstimates.penaltyFee = values[2];
        withdrawEstimates.newCashDeposited = values[3];
        withdrawEstimates.assetToSwap = values[5];
        withdrawEstimates.cashToSwap = values[0] + values[1] + values[2];
        return withdrawEstimates;
    }

    function getWithdrawEstimatesOf(
        address botPool,
        address account,
        uint amountTC,
        uint amountCash,
        bool withdrawNow
    ) public view returns (WithdrawEstimates memory withdrawEstimates) {
        IBotPool BotPool = IBotPool(botPool);
        uint BotPoolUserID = BotPool.userIDs(account);

        IBotController BotController = IBotController(BotPool.botController());

        if (BotPool.isRegistered(BotPoolUserID)) {
            IBotTrader BotTrader = BotPool.inBotTrader(BotPoolUserID);
            uint BotTraderUserID = BotTrader.userIDs(account);

            withdrawEstimates = _wrapWithdrawEstimates(BotTrader.getWithdrawEstimates(account, BotTraderUserID, amountCash, withdrawNow));
            FrontendLib_getUser.BotTraderReturns memory _user = FrontendLib_getUser.getBotTraderUser(BotTrader, BotTraderUserID);
            withdrawEstimates.currentTradePnL = int(_user.total) - int(_user.activeTradeStartingBalance); // TOTAL

            if (_user.total > _user.deposited) {
                withdrawEstimates.totalProfits = Caffeinated.fromPercent(_user.total - _user.deposited, withdrawEstimates.pctUserPosition); // == BotTrader.getBalanceOfUserID(BotTraderUserID);  pctPenaltyFeeOf
                withdrawEstimates.netProfit = Caffeinated.fromPercent(_user.total - (withdrawEstimates.profitFee + withdrawEstimates.penaltyFee), withdrawEstimates.pctUserPosition);
            }
            
            withdrawEstimates.newCashBalance = int(_user.total) - int(withdrawEstimates.cashToReceive + withdrawEstimates.profitFee + withdrawEstimates.penaltyFee);
            withdrawEstimates.releasedTcOperatingDeposit = BotPool._pctOperatingDeposit(BotPoolUserID, withdrawEstimates.pctUserPosition); // == Caffeinated.fromPercent(BotPool.operatingDepositTC(BotPoolUserID)

            // Modify the true balance down to only 98% to price in slippage when the Bot is in a trade
            if (BotPool.getTradeStatusOfID(BotPoolUserID) != 0 && withdrawEstimates.newCashBalance > 0) {
                
                if (_user.total > _user.activeTradeStartingBalance) {
                    withdrawEstimates.newCashBalance -= int((_user.total - _user.activeTradeStartingBalance) * BotController.pctProfitFeeOf(account) / BotController.oneHundredPct());
                }

                withdrawEstimates.newCashBalance *= int(BotController.minBalQualifyPct());
                withdrawEstimates.newCashBalance /= int(BotController.oneHundredPct());
            }
        }

        withdrawEstimates.newTcTotal = BotPool.balanceTC(BotPoolUserID);

        if (amountTC > withdrawEstimates.newTcTotal) {
            amountTC = withdrawEstimates.newTcTotal;
        }

        // Set the operating deposit estimates.
        uint newOperatingDeposit;
        if (BotPool.operatingDepositTC(BotPoolUserID) > withdrawEstimates.releasedTcOperatingDeposit) {
            newOperatingDeposit = BotPool.operatingDepositTC(BotPoolUserID) - withdrawEstimates.releasedTcOperatingDeposit;
        }

        // Set vested amount in estimates.
        if (BotPool.vested(0, 0) == 0) {
            withdrawEstimates.newTcVested = withdrawEstimates.newTcTotal - newOperatingDeposit;
        }
        else {
            FrontendLib_getUser.Vested memory _vested = FrontendLib_getUser.getVestedOfUserID(BotPool, BotPoolUserID);
            withdrawEstimates.newTcVested = _vested.total;
            withdrawEstimates.tcToReceive = amountTC;
        }

        // console.log(string.concat("withdrawEstimates.newTcTotal:  ", Caffeinated.uintToString(withdrawEstimates.newTcTotal)));
        // console.log(string.concat("withdrawEstimates.tcToReceive: ", Caffeinated.uintToString(withdrawEstimates.tcToReceive)));
        // console.log(string.concat("withdrawEstimates.newTcVested: ", Caffeinated.uintToString(withdrawEstimates.newTcVested)));
        // console.log(string.concat("newOperatingDeposit:           ", Caffeinated.uintToString(newOperatingDeposit)));
        // console.log(string.concat("withdrawEstimates.tcToReceive + withdrawEstimates.newTcVested + newOperatingDeposit: ", Caffeinated.uintToString(withdrawEstimates.tcToReceive + withdrawEstimates.newTcVested + newOperatingDeposit)));

        // Then edit total balance to reflect vested estimate.
        if (withdrawEstimates.tcToReceive + withdrawEstimates.newTcVested + newOperatingDeposit > withdrawEstimates.newTcTotal) {
            withdrawEstimates.tcToReceive = withdrawEstimates.newTcTotal - (withdrawEstimates.newTcVested + newOperatingDeposit);
        }
        // The `tcToReceive` is less than `totalTC` - `reservedTC` in this case.
        // else if (withdrawEstimates.tcToReceive > withdrawEstimates.newTcTotalBalance) {
        //     withdrawEstimates.tcToReceive = withdrawEstimates.newTcTotalBalance;
        //     delete withdrawEstimates.newTcTotalBalance;
        // }
        // else {
            
        // }

        // Then edit the total and available TC balance to reflect adjusted `amountTC` the user will actually receive.
        withdrawEstimates.newTcTotal -= withdrawEstimates.tcToReceive;
        withdrawEstimates.newTcBalance = withdrawEstimates.newTcTotal - newOperatingDeposit;

        if (withdrawEstimates.newTcBalance > 0 || withdrawEstimates.tcToReceive > 0) {

            uint tcWeeklyFee = BotController.tcFeeOf(account);

            if (tcWeeklyFee == 0 ||
                (withdrawEstimates.newTcBalance > 0
                && withdrawEstimates.newCashBalance == 0
                && withdrawEstimates.cashToReceive > 0)
            ) {
                withdrawEstimates.newGuaranteedBotRuntime = type(uint).max;
            }
            else {
                withdrawEstimates.newGuaranteedBotRuntime =
                    FrontendLib_getUser._calcDaysRemaining(
                        botPool,
                        tcWeeklyFee,
                        (withdrawEstimates.newTcBalance / tcWeeklyFee) + 1,
                        withdrawEstimates.newTcBalance,
                        0
                    );
            }
        }    
        return withdrawEstimates;
    }

    // If `newTcAvailableBalanceRequired` - `newTcAvailableBalance` > 0
    // then the user must deposit that much more TC. Otherwise if it's
    // negative or 0 exactly, the user's deposit will be accepted successfully.
    struct DepositEstimates {
        int addlTcNeededToDeposit;
        uint totalTcNeededToDeposit;
        int newTcTotal;
        int newTcBalance;
        uint newTcBalanceRequired;
        uint additionalTcOperatingDeposit;
        uint remainingWeeklyUpkeep;
        uint futureWeeklyUpkeep;
        uint newGuaranteedBotRuntime;
        uint newCashBalance;
    }

    function getDepositEstimatesOf(
        address botPool,
        address account,
        uint amountTC,
        uint amountCash
    ) external view returns (DepositEstimates memory) {
        IBotPool BotPool = IBotPool(botPool);
        uint BotPoolUserID = BotPool.userIDs(account);

        IBotController BotController = IBotController(BotPool.botController());

        int[9] memory _depositEstimates;
        _depositEstimates[5] = int(BotController.tcReqOperatingDepositOf(account, amountCash));
        _depositEstimates[2] = int(amountTC);
        _depositEstimates[3] = _depositEstimates[2] - _depositEstimates[5];
        uint cashInBot;

        if (BotPool.isRegistered(BotPoolUserID)) {
            IBotTrader BotTrader = BotPool.inBotTrader(BotPoolUserID);
            uint BotTraderUserID = BotTrader.userIDs(account);

            FrontendLib_getUser.BotTraderReturns memory _user = FrontendLib_getUser.getBotTraderUser(BotTrader, BotTraderUserID);
            if (_user.total > 0) {
                cashInBot = _user.total;

                // Modify the true balance down to only 98% to price in slippage when the Bot is in a trade
                if (BotPool.getTradeStatusOfID(BotPoolUserID) != 0) {
                    
                    if (_user.total > _user.activeTradeStartingBalance) {
                        cashInBot -= (_user.total - _user.activeTradeStartingBalance) * BotController.pctProfitFeeOf(account) / BotController.oneHundredPct();
                    }

                    cashInBot *= BotController.minBalQualifyPct();
                    cashInBot /= BotController.oneHundredPct();
                }
            }
            
            _depositEstimates[2] += int(BotPool.balanceTC(BotPoolUserID));
            _depositEstimates[3] += int(BotPool.balanceTC(BotPoolUserID)) - int(BotPool.operatingDepositTC(BotPoolUserID));
        }

        _depositEstimates[7] = int(BotController.tcFeeOf(account));

        if (cashInBot == 0
            && amountCash > 0
            && block.timestamp > BotPool.nextTimeUpkeep(BotPoolUserID)
            && block.timestamp < BotPool.nextTimeUpkeepGlobal()
        ) {
            _depositEstimates[6] = _calcTcReqUpkeepPayment(BotPool, BotController, account);
            _depositEstimates[2] -= _depositEstimates[6];
            _depositEstimates[3] -= _depositEstimates[6];
        }

        if (cashInBot > 0 || amountCash > 0) {
            _depositEstimates[4] = int(BotController.minReqBalTC()); // + _depositEstimates[5] + _depositEstimates[6];
        }

        // To get the /additional/ amount of TC the user must deposit: `newTcAvailableBalanceRequired` - `newTcAvailableBalance`
	    // To directly get the exact amount BotPool requires: `newTcAvailableBalanceRequired` + `additionalTcOperatingDeposit` + `remainingWeeklyUpkeep`
        _depositEstimates[0] = _depositEstimates[4] - _depositEstimates[3];
        if (_depositEstimates[0] < 0) {
            delete _depositEstimates[0];
        }

        // Has the Insane or has no cash in bot and is not depositing any cash.
        // In these two scenarios, the user should receive infinite days remaining.
        if (_depositEstimates[0] == 0) {
            if (_depositEstimates[7] == 0 || (cashInBot == 0 && amountCash == 0)) {
                _depositEstimates[8] = type(int).max;
            }
            else if (_depositEstimates[3] > 0 && (cashInBot > 0 || amountCash > 0)) {
                // Make sure we catch the underflow such that if the `newTcAvailableBalance` is negative
                // it returns 0 rather than some enormous underflow number in uint form.
                _depositEstimates[8] =
                    int(FrontendLib_getUser._calcDaysRemaining(
                        botPool,
                        uint(_depositEstimates[7]),
                        (uint(_depositEstimates[3]) / uint(_depositEstimates[7])) + 1,
                        uint(_depositEstimates[3]),
                        0
                    )
                );
            }
        }

        return
            DepositEstimates(
                _depositEstimates[0],
                uint(_depositEstimates[4] + _depositEstimates[5] + _depositEstimates[6]),
                _depositEstimates[2],
                _depositEstimates[3],
                uint(_depositEstimates[4]),
                uint(_depositEstimates[5]),
                uint(_depositEstimates[6]),
                uint(_depositEstimates[7]),
                _depositEstimates[8] == type(int).max ? type(uint).max : uint(_depositEstimates[8]),
                cashInBot + amountCash
            );
    }

    function _calcTcReqUpkeepPayment(IBotPool BotPool, IBotController BotController, address account) private view returns (int) {
        return int(
            BotController.tcReqUpkeepPaymentOf(account,
                int(BotPool.nextTimeUpkeepGlobal()) - int(block.timestamp)
            )
        );
    }

}