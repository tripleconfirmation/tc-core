// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

library SignableTXStruct {

    struct SignableTransaction {
        bytes32 functionName;       // name of the setter function to be called
        bytes32 inputs;             // checksum of inputs being sent to the function
        uint[] uintInput;           // uint input(s) to be sent to the setter function
        address[] addressInput;     // address input(s) to be sent to the setter function
        uint[] signatures;          // list of editorIDs that have signed this transaction
        uint lastTimeSigned;        // the last time this transaction was signed or unsigned
    }

}