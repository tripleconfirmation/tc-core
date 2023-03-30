// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

// import "hardhat/console.sol";

library Caffeinated {

    // for use with calculations that do division->variable storage->division
    uint internal constant precision = 10 ** 18;

    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    function _uintToString(uint value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint temp = value;
        uint digits;
        while (temp != 0) {
            ++digits;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            --digits;
            buffer[digits] = bytes1(uint8(48 + uint(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    function uintToString(uint value) internal pure returns (string memory) {
        return _uintToString(value);
    }

    /*
     * @dev Converts a `uint` to its ASCII `string` decimal representation.
     * @param `denominator` MUST be either exactly 1, or evenly divisible by 10.
     */
    function uintToString(uint value, uint denominator) internal pure returns (string memory str) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (denominator % 10 > 0) {
            denominator -= denominator % 10;
        }

        if (denominator == 0) {
            denominator = 1;
        }

        // String containing whole numbers only.
        str = _uintToString(value / denominator);

        if (denominator > 9) {
            uint decimalToShow;

            // Let's generate a nice, clear error message with the proper decimals.
            // We need to use assembly to achieve a proper, non-overflowing modulo.
            assembly { decimalToShow := mod(value, denominator) }

            // Now generate the decimals string, fixed to the number of global `decimals`.
            string memory strDecimals = _uintToString(decimalToShow);

            if (decimalToShow > 0) {
                for (; decimalToShow < denominator / 10; decimalToShow *= 10) {
                    strDecimals = string.concat("0", strDecimals);
                }
            }

            // Lastly, assemble the string.
            str = string.concat(str, ".", strDecimals);
        }
        return str;
    }

    function intToString(int value) internal pure returns (string memory) {
        return intToString(value, 1);
    }

    function intToString(int value, uint denominator) internal pure returns (string memory) {
        if (value < 0) {
            // Convert the `value` negative and signed integer to a positive
            // uint by multiplying it by -1. Affix the negative signer "-" string
            // designation as its suffix upon return.
            return string.concat("-", uintToString(uint(-1 * value), denominator));
        }
        return uintToString(uint(value), denominator);
    }

    function toPercent(uint amount, uint relativeTo) internal pure returns (uint) {
        return precision * amount / relativeTo;
    }

    function fromPercent(uint amount, uint relativeTo) internal pure returns (uint) {
        return relativeTo * amount / precision;
    }

    // Used in... many, many places.
    function stringsAreIdentical(string memory a, string memory b) external pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    // Used by `BotPool.ejectBadUsers()`
    function bytesAreIdentical(bytes memory a, bytes calldata b) external pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function _char(bytes1 b) private pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function addressToString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; ++i) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = _char(hi);
            s[2*i+1] = _char(lo);            
        }
        return string(s);
    }

    function toBytes(uint[] memory a, address[] memory b) external pure returns (bytes memory) {
        return abi.encodePacked(a, b);
    }

}