// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.19;

import "./IBotPool.sol";

interface IBotFactory {

    // ### VIEW FUNCTIONS ###
    function botPool() external view returns (IBotPool BotPool);
    function isSet() external view returns (bool isSet);




    // ### SETUP FUNCTIONS ###
    function setBotPool(address newBotPool) external;




    // ### FACTORY FUNCTIONS ###
    function makeNewBotTrader() external returns (address newBotTrader);

}