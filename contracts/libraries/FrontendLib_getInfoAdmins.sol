// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./Caffeinated.sol";

import "./FrontendLib_getInfo.sol";

library FrontendLib_getInfoAdmins {

    // To keep the same structure as returned from `getInfo()`
    // Example: `info.tcc.rewards.nextUser`
    struct TCC {
        FrontendLib_getInfo.Rewards rewards;
    }

    struct AdminInfo {
        address loopWallet; // the almighty loop wallet
        BotControllerLib_structs.Editors editors;
        address[] permittedUsers;
        uint nextPermittedUserToDelete;
        address[] sanctionedUsers;
        uint nextSanctionedUserToDelete;
        BotControllerLib_structs.Upkeep upkeep;
        TCC tcc;
        uint nextUserIDToEvict;
        address setNewBotController_nextBotPool; // BotController.setNewBotController_nextBotPool()
        FrontendLib_getInfo.BotTradersAdmins botTraders;
        address[] aTokens;
    }

    function getInfoAdmins(address botPool) external view returns (AdminInfo memory) {
        IBotPool BotPool = IBotPool(botPool);

        require(
            BotPool.sysGetLevel(msg.sender),
            "FRONTEND | AUTH: Sender of `getInfoAdmins()` must be a member of the admin team."
        );

        IBotController BotController = BotPool.botController();
        BotControllerLib_structs.Editor[] memory editorList = BotController.getEditorListFrontend(msg.sender);

        // console.log("Checkpoint passed. `getInfoAdmins()`");
        // console.log(Caffeinated.uintToString(BotController.numEditors()));

        return AdminInfo(
            BotController.getLoopWalletFrontend(msg.sender),
            BotControllerLib_structs.Editors(
                BotController.numEditors(),
                editorList.length,
                BotController.maxEditors(),
                editorList,
                BotController.maxPendingTX(),
                BotController.getSignableTransactionsFrontend(msg.sender)
            ),
            BotController.getPermittedUsersList(),
            BotController.nextPermittedUserToDelete(),
            BotController.getSanctionedUsersList(),
            BotController.nextSanctionedUserToDelete(),
            BotControllerLib_structs.Upkeep(
                BotPool.nextTimeUpkeepGlobal(),
                BotController.weeklyFeeTimeSlippage(),
                BotPool.nextTimeUpkeepGlobal() - BotController.weeklyFeeTimeSlippage(),
                BotPool.getNextUserIDToUpkeep(),
                BotPool.getCurrentIndexOfBadUserIDs(),
                BotPool.getBadUserIDs(),
                BotPool.getBadUserAddresses()
            ),
            TCC(
                FrontendLib_getInfo.getRewardsInfo(botPool)
            ),
            BotPool.getNextUserIDToEvict(),
            BotController.getSetNewBotController_nextBotPoolFrontend(msg.sender),
            FrontendLib_getInfo.getBotTraderObject(botPool, msg.sender),
            BotPool.getaTokens()
        );
    }

}