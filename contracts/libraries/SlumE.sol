// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./Caffeinated.sol";

library SlumE {

    function errorMsg(
        string memory headerMsg,
        uint limit,
        bool isGreaterThan,
        uint value,
        string memory symbol,
        uint decimals,
        string memory footerMsg
    ) internal pure {
        require(
            isGreaterThan ? limit >= value : limit <= value,
            string.concat(
                headerMsg,
                Caffeinated.uintToString(limit, decimals),
                " ",
                symbol,
                footerMsg
            )
        );
    }

}