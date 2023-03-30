// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.19;

import "./Baked.sol";
import "./BotTrader.sol";

import "./interfaces/IBotPool.sol";

contract BotFactory {

    IBotPool public botPool;
    bool public isSet;

    constructor() {
        // simply to ensure `makeNewBotTrader()` can't be called from address(0)
        botPool = IBotPool(msg.sender);
    }




    // ### AUTHORISATION FUNCTIONS ###
    modifier _botPoolAuth() {
        require(msg.sender == address(botPool), "BOT FACTORY | AUTH ERROR: Sender is not the BotPool contract.");
        _;
    }




    // ### SETUP FUNCTIONS ###
    function setBotPool(address newBotPool) external _botPoolAuth {
        require(!isSet, "BOT FACTORY | SET ERROR: BotPool contract has already been set.");
        botPool = IBotPool(newBotPool);

        require(address(botPool.botFactory()) == address(this), "BOT FACTORY | SET ERROR: BotPool's BotFactory is not this contract.");
        isSet = true;
    }




    // ### FACTORY FUNCTIONS ###
    function makeNewBotTrader() external _botPoolAuth returns (address newBotTrader) {
        BotTrader _BotTrader = new BotTrader(address(botPool));
        return address(_BotTrader);
    }

}