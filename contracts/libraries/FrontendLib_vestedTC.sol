// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./Caffeinated.sol";

import "../interfaces/IBotPool.sol";

library FrontendLib_vestedTC {

    uint8 public constant t = 5; // MUST == BotPool.t();
    uint8 public constant u = 4; // MUST == number of values in the `getVestingHash..()` functions

    function checkVestedTC_vs_newBotPool(address botPool, address _newBotPool) external view returns (bool, uint) {
        IBotPool newBotPool = IBotPool(_newBotPool);
        IBotPool BotPool = IBotPool(botPool);
        uint numUsers = BotPool.numUsers();
        uint newNumUsers = newBotPool.numUsers();
        
        require(
            newNumUsers == numUsers,
            string.concat(
                "GET-INFO | NEW BOT POOL: New BotPool does not contain all users: ",
                Caffeinated.uintToString(newNumUsers),
                " in New BotPool vs ",
                Caffeinated.uintToString(numUsers),
                " in Existing BotPool.",
                " (5)"
            )
        );

        uint i;
        bool identicalBalances = true;
        uint[t] memory vestedInfo; // = BotPool.vested(0);
        uint[t] memory vestedNew;

        for (; i <= numUsers; ++i) {
            if (identicalBalances) {
                vestedInfo = BotPool.getVestedValues(i);
                vestedNew = newBotPool.getVestedValues(i);
                for(uint8 x; x < t; ++x) {
                    identicalBalances = vestedInfo[x] == vestedNew[x];
                    if (!identicalBalances) {
                        break;
                    }
                }
                identicalBalances = BotPool.userAddress(i) == newBotPool.userAddress(i);
            }
            else {
                break;
            }
        }

        return (identicalBalances, i);
    }

    function checkVestedTC_vs_unnamedArrays(address botPool, address[] calldata userAddress, uint[t][] calldata vested) external view returns (bool, uint) {
        IBotPool BotPool = IBotPool(botPool);
        uint numUsers = BotPool.numUsers();

        require(
            vested.length == numUsers + 1 && userAddress.length == numUsers + 1,
            string.concat(
                "GET-INFO | VESTED TC ARRAY: Given arrays do not contain all users: ",
                Caffeinated.uintToString(vested.length),
                " given vs ",
                Caffeinated.uintToString(numUsers + 1),
                " required.",
                " (1)"
            )
        );

        uint i;
        bool identicalBalances = true;
        uint[t] memory vestedInfo; // = BotPool.vested(0);

        for (; i <= numUsers; ++i) {
            vestedInfo = BotPool.getVestedValues(i);
            if (identicalBalances) {
                identicalBalances = BotPool.userAddress(i) == userAddress[i];
            }

            if (!identicalBalances) break;

            for(uint8 x; x < t; ++x) {
                identicalBalances = vestedInfo[x] == vested[i][x];
                if (!identicalBalances) break;
            }
        }

        return (identicalBalances, i);
    }

    function getVestedTCUnnamed(address botPool) external view returns (uint[t][] memory) {
        IBotPool BotPool = IBotPool(botPool);
        uint[t][] memory vestedValues = new uint[t][](BotPool.numUsers() + 1); // CAN'T FIGURE THIS OUT

        for (uint i; i < vestedValues.length; ++i) {
            vestedValues[i] = BotPool.getVestedValues(i);
        }
        
        return vestedValues;
    }

    function getUserAddresses(address botPool) external view returns (address[] memory) {
        IBotPool BotPool = IBotPool(botPool);
        address[] memory userAddress = new address[](BotPool.numUsers() + 1);

        for (uint i; i < userAddress.length; ++i) {
            userAddress[i] = BotPool.userAddress(i);
        }

        return userAddress;
    }
            
    function getVestingHashFromUnnamed(address botPool, address[] calldata userAddress, uint[t][] calldata vestedValues) external view returns (bytes32) {
        IBotPool BotPool = IBotPool(botPool);
        uint numUsers = BotPool.numUsers();

        require(
            vestedValues.length == numUsers + 1,
            string.concat(
                "GET-INFO | GET VESTING HASH: Given arrays do not contain all users: ",
                Caffeinated.uintToString(vestedValues.length),
                " given vs ",
                Caffeinated.uintToString(numUsers + 1),
                " required.",
                " (4)"
            )
        );

        uint vestingHashLength = BotPool.vestingHashLength();
        bytes32 vestingHashBalance;

        for(uint i; i < vestingHashLength; ++i) {
            vestingHashBalance = keccak256(abi.encode(vestingHashBalance, vestedValues[i]));
        }

        // `block.timestamp / 100 % numUsers` ensures a different random user is chosen at least every 180 seconds.
        // Also means the hash will only be valid for up to 180 seconds.
        uint[u] memory indexes = [BotPool.vestingFrozen() ? numUsers : 0, numUsers - 1, numUsers / 2, (block.timestamp / 300) % numUsers];

        return _getVestingHashStackTooDeepUnnamed(botPool, userAddress, vestedValues, vestingHashBalance, indexes);
    }

    function _getVestingHashStackTooDeepUnnamed(
        address botPool,
        address[] calldata userAddress,
        uint[t][] calldata vestedValues,
        bytes32 vestingHashBalance,
        uint[u] memory indexes
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    botPool,
                    indexes[0],
                    vestedValues[0],
                    vestedValues[indexes[1]],
                    vestedValues[indexes[2]],
                    vestedValues[indexes[3]],
                    userAddress[indexes[1]],
                    userAddress[indexes[2]],
                    userAddress[indexes[3]],
                    vestingHashBalance
                )
            );
    }

    function checkVestedTC_vs_namedArray(address botPool, Vested[] calldata vestedObj) external view returns (bool, uint) {
        IBotPool BotPool = IBotPool(botPool);
        uint numUsers = BotPool.numUsers();

        require(
            vestedObj.length == numUsers + 1,
            string.concat(
                "GET-INFO | VESTED TC ARRAY: Given arrays do not contain all users: ",
                Caffeinated.uintToString(vestedObj.length),
                " given vs ",
                Caffeinated.uintToString(numUsers + 1),
                " required.",
                " (2)"
            )
        );

        uint i;
        bool identicalBalances = true;
        uint[t] memory vestedInfo; // = BotPool.vested(0);

        for (; i <= numUsers; ++i) {
            vestedInfo = BotPool.getVestedValues(i);
            identicalBalances =
                BotPool.userAddress(i) == vestedObj[i].account
                && vestedInfo[0] == vestedObj[i].timeLastClaimed
                && vestedInfo[1] == vestedObj[i].oneYear
                && vestedInfo[2] == vestedObj[i].twoYears
                && vestedInfo[3] == vestedObj[i].threeYears
                && vestedInfo[4] == vestedObj[i].fourYears;
            
            if (!identicalBalances) break;
        }

        return (identicalBalances, i);
    }

    struct Vested {
        address account;
        uint timeLastClaimed;
        uint oneYear;
        uint twoYears;
        uint threeYears;
        uint fourYears;
    }

    function getVestedTCNamed(address botPool) external view returns (Vested[] memory) {
        IBotPool BotPool = IBotPool(botPool);
        Vested[] memory _vestedUsers = new Vested[](BotPool.numUsers() + 1);
        uint[t] memory vested;
        
        for (uint i; i < _vestedUsers.length; ++i) {
            vested = BotPool.getVestedValues(i);
            _vestedUsers[i] = Vested(
                BotPool.userAddress(i),
                vested[0],
                vested[1],
                vested[2],
                vested[3],
                vested[4]
            );
        }

        return _vestedUsers;
    }

    // - - - - - which one do we prefer??
    // OPTION A
    function getVestingHashFromNamed(address botPool, Vested[] calldata vestedObj) external view returns (bytes32) {
        IBotPool BotPool = IBotPool(botPool);
        uint numUsers = BotPool.numUsers();

        require(
            vestedObj.length == numUsers + 1,
            string.concat(
                "GET-INFO | GET VESTING HASH: Given object does not contain all users: ",
                Caffeinated.uintToString(vestedObj.length),
                " given vs ",
                Caffeinated.uintToString(numUsers + 1),
                " required.",
                " (3)"
            )
        );

        uint vestingHashLength = BotPool.vestingHashLength();
        bytes32 vestingHashBalance;

        address[] memory userAddress = new address[](vestedObj.length); // setting a static length saves ≈ 300 gas per user
        uint[t][] memory vested = new uint[t][](vestedObj.length);
        uint[u] memory indexes = [BotPool.vestingFrozen() ? numUsers : 0, numUsers - 1, numUsers / 2, (block.timestamp / 300) % numUsers];

        for(uint i; i < vested.length; ++i) {
            userAddress[i] = vestedObj[i].account;
            vested[i] = [vestedObj[i].timeLastClaimed, vestedObj[i].oneYear, vestedObj[i].twoYears, vestedObj[i].threeYears, vestedObj[i].fourYears];

            if (i < vestingHashLength) {
                vestingHashBalance = keccak256(abi.encode(vestingHashBalance, vested[i]));
            }
        }

        return
            keccak256(
                abi.encode(
                    botPool,
                    indexes[0],
                    vested[0],
                    vested[indexes[1]],
                    vested[indexes[2]],
                    vested[indexes[3]],
                    userAddress[indexes[1]],
                    userAddress[indexes[2]],
                    userAddress[indexes[3]],
                    vestingHashBalance
                )
            );
    }

}