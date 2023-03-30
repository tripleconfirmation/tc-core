// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";

uint8 constant _t = 5;
uint8 constant _n = 6;

library PresaleLib_structs {

    struct Spent {
        uint usdc;
        uint usdc_e;
    }

    // struct NFTRewards {
    //     bool all;
    //     bool silver;
    //     bool gold;
    //     bool legendary;
    //     bool insane;
    // }

    struct Balance {
        uint current; // current balance; available to vest or to be withdrawn at CROWDFUND end
        uint aggregate; // running total going up only when TC is added
        uint bonus; // total bonus TC ever received by this user via Vesting
        uint bonusFromReferralsYours;
        uint bonusFromReferralsOthers;
        uint vested; // amount of TC vested; cumulative; used for `extraBonusThreshold` 2% on 100k TC
        uint tcc;
    }

	struct UserStruct {
        uint userID;
        address adresse;
        bool isRegistered;

        // `nftRewards` MUST be an array of bool
        // in order to be easily loopable in the `vestTC()`
        // function in the Presale contract. We'd love to have
        // named outputs but going with a simple array of bool
        // is vastly easier in verifying and executing the
        // Vesting+ feature set.
        bool[_t] nftRewards;
        Spent spent;
        Balance balance;
        string referralCode;
    }

	struct Info {
        // User user;
        uint numUsers;
        uint[_n] TCRounds;
        uint[_n] USDPrice;
        uint currentRound;
        uint totalTC;
        uint totalSpentUSD;
        uint totalPurchasedTC;
        uint totalPurchasedTCSinceLastRound;
        uint totalTCGivenForReferrals;
    }

    struct Contribution {
        address userAddress;
        uint amountUSD;
        uint amountTC;
    }

    function emptyUser() external pure returns (UserStruct memory) {
        return UserStruct(
            0,
            address(0),
            false,
            [false, false, false, false, false],
            Spent(
                0,
                0
            ),
            Balance(
                0,
                0,
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );
    }

}