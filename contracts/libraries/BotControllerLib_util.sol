// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.19;

import "./Caffeinated.sol";

import "./BotControllerLib_structs.sol";

import "../interfaces/IBotController.sol";
import "../interfaces/IBotPool.sol";
import "../interfaces/IBotTrader.sol";
import "../interfaces/INFTAdmin.sol";

// these functions have been tested to save the optimal amount of byte code in BotController
library BotControllerLib_util {

    // ### CHECK SET FUNCTIONS ###
    function _createDynamicArrs(uint uintLen, uint addressLen) public pure returns (uint[] memory, address[] memory) {
        uint[] memory uintArr = new uint[](uintLen);
        address[] memory addressArr = new address[](addressLen);
        return (uintArr, addressArr);
    }

    function checkSetNftAdmin(address newNftAdmin) external returns (bool) {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(0, 1);
        addressArr[0] = newNftAdmin;

        IBotController BotController = IBotController(address(this));
        INFTAdmin _newNftAdmin = INFTAdmin(newNftAdmin);
        INFTAdmin _currentNftAdmin = BotController.nftAdmin();
        address[][] memory allNFTsFromNew = _newNftAdmin.getAllNFTs();
        address[][] memory allNFTsFromOld = _currentNftAdmin.getAllNFTs();

        require(allNFTsFromNew.length == allNFTsFromOld.length, "TEAM | SET NFT ADMIN: List of NFTs are not identical.");

        if (!BotController.doMultisig(msg.sender, "setNftAdmin", uintArr, addressArr)) {
            return false;
        }

        bool allSameNFTs = true;

        for (uint i; i < allNFTsFromNew.length; ++i) {
            if (!allSameNFTs) break;
            for (uint x = 0; x < allNFTsFromNew[i].length; ++x) {
                if (
                    allNFTsFromOld[i][x] != allNFTsFromNew[i][x]
                    || _currentNftAdmin.getLevelOf(allNFTsFromOld[i][x]) != _newNftAdmin.getLevelOf(allNFTsFromNew[i][x])
                ) {
                    allSameNFTs = false;
                    break;
                }
            }
        }

        return allSameNFTs;
    }

    function checkSetTCUpkeep(uint _tcUpkeep) external returns (bool) {
        IBotController BotController = IBotController(address(this));
        require(
            (block.timestamp + BotController.weeklyFeeTimeSlippage()) >= BotController.lastTimeUpkeepModified() + BotController.secPerWeek(),
            "TEAM | UPKEEP: Cannot change weekly upkeep more than once per week."
        );

        // + 19 ensures it rounds up
        uint tcUpkeep = BotController.tcUpkeep();
        require(
            _tcUpkeep <= tcUpkeep + uint((tcUpkeep + 19) / 20),
            "TEAM | UPKEEP: Cannot increase weekly upkeep by more than 5%."
        );
        require(
            _tcUpkeep >= 20,
            "TEAM | UPKEEP: Cannot decrease weekly upkeep below 0.000020 TC."
        );

        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, 0);
        uintArr[0] = _tcUpkeep;

        if (!BotController.doMultisig(msg.sender, "setTCUpkeep", uintArr, addressArr)) {
            return false;
        }

        return true;
    }

    function checkSetMinFutureWeeksTCDeposit(uint8 _minFutureWeeksTCDeposit) external returns (bool) {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, 0);
        uintArr[0] = _minFutureWeeksTCDeposit;

        if (!IBotController(address(this)).doMultisig(msg.sender, "setMinFutureWeeksTCDeposit", uintArr, addressArr)) {
            return false;
        }

        return true;
    }

    function checkSetProfitFee(uint _profitFee) external view returns (bool) {
        IBotController BotController = IBotController(address(this));

        require(block.timestamp - BotController.lastTimeProfitFeeModified() >= BotController.secPerWeek(),
            "TEAM | NET-PROFIT: Cannot change net-profit fee more than once per week."
        );

        uint profitFee = BotController.profitFee();
        require(_profitFee <= profitFee + uint((profitFee + 19) / 20),
            "TEAM | NET-PROFIT: Cannot increase net-profit fee by more than 5% in a week."
        );
        require(_profitFee <= 40 * BotController.oneHundredPct() / 100, "TEAM | NET-PROFIT: Cannot increase net-profit fee above 40%.");

        return true;
    }

    function checkSetPercentages(uint[] memory _percents) external view {
        require(_percents.length == 8, "TEAM | DEX %: Parameters array must have a length of 8.");

        uint oneHundredPct = IBotController(address(this)).oneHundredPct();
        require(_percents[4] <= oneHundredPct * 20 / 100, "TEAM | OVERSWAP %: Cannot be greater than 20.0%.");
        require(_percents[4] >= _percents[0] + _percents[3], "TEAM | OVERSWAP %: Cannot be less than Slippage % + Dex Fee %.");
        require(_percents[5] >= oneHundredPct * 90 / 100, "TEAM | MIN BAL QUALIFY %: Cannot be less than 90.0%.");
        require(_percents[6] <= oneHundredPct * 5 / 100, "TEAM | SHORT SLIPPAGE %: Cannot be greater than 5.0%.");
        require(_percents[1] + _percents[2] <= oneHundredPct * 90 / 100, "TEAM | BORROW % + RESERVE %: Must be less than 90.0% when summed.");
        require(_percents[7] >= _percents[6], "TEAM | SHORT EMERGENCY %: Cannot be greater than Short Slippage %.");
        require(_percents[7] <= oneHundredPct / 10, "TEAM | SHORT EMERGENCY %: Cannot be greater than 10.0%.");

        for (uint i; i < _percents.length; ++i) {
            require(
                _percents[i] <= oneHundredPct,
                "TEAM | DEX: Cannot set any DEX percentage to greater than 100.0%."
            );
        }
    }

    function checkSetPermittedUsersList(address[] memory accounts, uint[] memory isPermitted) external returns (bool) {
        require(accounts.length == isPermitted.length, "TEAM LIB | SET PERMITTED USERS: Both arrays must be the same length.");

        IBotController BotController = IBotController(address(this));
        uint maxSingleLoopSize = BotController.maxSingleLoopSize();

        require(
            accounts.length <= maxSingleLoopSize,
            string.concat(
                "TEAM LIB | SET PERMITTED USERS: Maximum array length of ",
                BotController.strMaxSingleLoopSize(),
                " allowed."
            )
        );

        if (!BotController.doMultisig(msg.sender, "setPermittedUsersList", isPermitted, accounts)) {
            return false;
        }

        return true;
    }

    function checkSetSanctionedUsersList(address[] memory accounts, uint[] memory isSanctioned) external returns (bool) {
        require(accounts.length == isSanctioned.length, "TEAM LIB | SET SANCTIONED USERS: Both arrays must be the same length.");

        IBotController BotController = IBotController(address(this));
        uint maxSingleLoopSize = BotController.maxSingleLoopSize();

        require(
            accounts.length <= maxSingleLoopSize,
            string.concat(
                "TEAM LIB | SET SANCTIONED USERS: Maximum array length of ",
                BotController.strMaxSingleLoopSize(),
                " allowed."
            )
        );

        if (!BotController.doMultisig(msg.sender, "setSanctionedUsersList", isSanctioned, accounts)) {
            return false;
        }

        return true;
    }




    // ### MISC FUNCTIONS ###
    function runSetTCCRewardsFrozen(bool usersShouldEarnRewards, address[] memory _BotPools) external returns (uint8, address, uint) {
        (uint[] memory uintArr, ) = _createDynamicArrs(1, 0);
        uintArr[0] = usersShouldEarnRewards ? 1 : 0; // 0 = false, 1 = true

        IBotController BotController = IBotController(address(this));

        (, address[] memory addressArr) = _createDynamicArrs(0, _BotPools.length);
        addressArr = _BotPools;
        if (!BotController.doMultisig(msg.sender, "loop_setTCCRewardsFrozen", uintArr, addressArr)) {
            return (0, _BotPools[0], 0);
        }

        // 800 is the cost to set a non-changing variable. Multiply by 5 to safely pad any extra costs.
        uint oneLoopGasUsed = (4000 * BotController.maxSingleLoopSize()) + BotController.minGas();
        
        // Before we even start the loop, make sure sufficient gas exists to complete
        // one full BotPool and its children.
        require(
            gasleft() > oneLoopGasUsed,
            string.concat(
                "TEAM | GAS: Insufficient remaining. Must start with at least ",
                Caffeinated.uintToString(oneLoopGasUsed),
                " gas. (3)"
            )
        );

        // uint desiredCount = usersShouldEarnRewards ? 1 : 0;

        for (uint i; i < _BotPools.length; ++i) {
            IBotPool BotPool = IBotPool(_BotPools[i]);
            while (BotPool.tccNextUserToReward() != uintArr[0]) {
                uint gas = BotPool.saveUsersTCCRewards();

                // Returns the `desiredCount` if successful
                // or the amount of gas missing if incomplete.
                if (gas > gasleft()) {
                    return (1, _BotPools[i], gas);
                }
            }
        }

        return (2, address(0), 0);
    }

    // NEW for Alpha v2
	// function weeklyFee(address botPool) external {
    //     // With all the verification checks in BotPool, we don't need to require
    //     // multi-sig transactions for editors.

    //     // (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(0, 1);
    //     // addressArr[0] = BotPool;

    //     // if (!IBotController(address(this)).doMultisig(msg.sender, "weeklyFee", uintArr, addressArr)) {
    //     //     return;
    //     // }

    //     IBotPool(botPool).weeklyFee();
    // }

	// NEW for Alpha v2
    function ejectBadUser(address BotPool, address account) external {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(2, 1);
        addressArr[0] = BotPool;
        uintArr[0] = uint(uint160(account));

        if (!IBotController(address(this)).doMultisig(msg.sender, "ejectBadUser", uintArr, addressArr)) {
            return;
        }

        IBotPool(BotPool).ejectBadUser(account);
    }

    // 0.1 Kb
    function ejectBadUserID(address BotPool, uint userID) external {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(2, 1);
        addressArr[0] = BotPool;
        uintArr[0] = userID;

        if (!IBotController(address(this)).doMultisig(msg.sender, "ejectBadUserID", uintArr, addressArr)) {
            return;
        }

        IBotPool(BotPool).ejectBadUserID(userID);
    }

    function freezeMigrateVestedTC(address botPool, bool vestingStatus) external returns (bool) {
        IBotController BotController = IBotController(address(this));

        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, 1);
        uintArr[0] = vestingStatus ? 1 : 0; // 0 = false, 1 = true
        addressArr[0] = botPool;

        if (!BotController.doMultisig(msg.sender, "freezeMigrateVestedTC", uintArr, addressArr)) {
            return false;
        }

        IBotPool BotPool = IBotPool(botPool);
        BotPool.freezeMigrateVestedTC(vestingStatus);

        if (BotPool.vestingHashLength() >= BotPool.numUsers()) {
            return true;
        }

        return false;
    }

    function checkSetWeeklyFeeWallet(address newWeeklyFeeWallet, address botPool) external returns (bool) {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(0, 2);
        addressArr[0] = newWeeklyFeeWallet;
        addressArr[1] = botPool;

        IBotController BotController = IBotController(address(this));

        if (!BotController.doMultisig(msg.sender, "setWeeklyFeeWallet", uintArr, addressArr)) {
            return false;
        }

        if (botPool == address(0) || botPool == address(this)) {
            return true;
        }
        
        IBotPool(botPool).setWeeklyFeeWallet(newWeeklyFeeWallet);
        return false;
    }

}