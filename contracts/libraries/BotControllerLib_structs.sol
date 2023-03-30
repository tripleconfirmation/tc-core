// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.19;

library BotControllerLib_structs {

    struct SignableTransaction {
        bytes32 functionName;       // name of the setter function to be called
        bytes32 inputs;             // checksum of inputs being sent to the function
        uint[] uintInput;           // uint input(s) to be sent to the setter function
        address[] addressInput;     // address input(s) to be sent to the setter function
        uint[] signatures;          // list of editorIDs that have signed this transaction
        uint lastTimeSigned;        // the last time this transaction was signed or unsigned
    }
    
    struct Editor {
        uint editorID;
        address editorAddress;
    }

    struct Editors {
        uint num;
        uint active;
        uint max;
        Editor[] list;
        uint maxPendingTX;              // maximum number of pending editor multisig transactions at once
        SignableTransaction[] signableTransactions; // a list of all pending editor multisig transactions
    }

    struct Upkeep {
        uint timeNext;                  // time the next upkeep can be run
        uint timeSlippage;              // can run the weekly fee `timeSlippage` earlier, to correct for missed weekly fee transactions
        uint timeMin;                   // equals `nextTime` minus `weeklyFeeTimeSlippage`
        uint nextUserIDToUpkeep;        // `nextUserIDToUpkeep` keep running the Weekly Fee function until this == 1
        uint currentIndexOfBadUserIDs;  // next bad user to evict
        uint[] badUserIDs;              // list of all bad users ids to evict
        address[] badUserAddresses;     // list of all bad users addresses to evict
    }

    // struct AdminInfo {
    //     address loopWallet;             // the almighty loop wallet
    //     Editors editors;
    //     address[] permittedUsers;
    //     uint nextPermittedUserToDelete;
    //     address[] sanctionedUsers;
    //     uint nextSanctioneddUserToDelete;
    //     Upkeep upkeep;
    //     uint nextUserToEvict;
    //     address setNewBotController_nextBotPool; // BotController.setNewBotController_nextBotPool()
    // }

}
    