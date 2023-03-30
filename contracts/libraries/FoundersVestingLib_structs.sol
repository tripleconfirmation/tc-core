// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";

library FoundersVestingLib_structs {

    struct Token {
        address adresse;                // address of this currency
        string symbol;                  // symbol of this currency
        uint8 decimals;                 // number of decimals this currency has
        uint denominator;               // divide by this number to get balance/value in decimal form
        address adminWallet;            // only used on TC/TCC: owner/admin wallet of this currency
        address treasuryWallet;         // only used on TC/TCC: treasury wallet of this currency
        uint circulatingSupply;         // only used on TC/TCC: circulating supply of this currency
        uint allocation;
        uint remaining;
        uint claimable;
        uint claimed;
        uint lastTimeClaimed;
    }

    struct TokenUSD {
        address adresse;
        string symbol;
        uint8 decimals;
        uint denominator;
        uint allocation;
        uint remaining;
        uint claimable;
        uint claimed;
        uint lastTimeClaimed;
    }

    struct Founder {
        address adresse;
        uint founderID;
        bool isFounder;
        Token tc;
        Token tcc;
        TokenUSD usdc;
        TokenUSD usdce;
        uint timeStart;
        uint timeEnd;
    }

    struct Permit {
        address account;
        uint approveAmount;
        uint deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function emptyTokenUSD(IERC20 USDC) external view returns (TokenUSD memory _tokenUSD) {
        return TokenUSD(address(USDC), USDC.symbol(), USDC.decimals(), 10 ** USDC.decimals(), 0, 0, 0, 0, 0);
    }

    function emptyFounder() external pure returns (Founder memory _founder) {
        return _founder;
    }
}