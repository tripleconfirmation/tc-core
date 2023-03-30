// SPDX-License-Identifier: WTFPL


// = = = = = = = = = = = = = = = = = //
//                                   //
//  Written by  Triple Confirmation  //
//                                   //
//           28 March 2023           //
// = = = = = = = = = = = = = = = = = //


pragma solidity ^0.8.19;

// `Baked` purposefully not imported.
// Removing `contractIsFrozen` ensures
// transfers cannot be stopped, thus
// guaranteeing users full ownership
// over their tokens. ++decentralisation.
import "./interfaces/IERC20.sol";

// ERC-20 and EIP-2612 compatible.
contract TokenBase {

    // Storage optimizations:
    // https://www.graduate.nu.ac.th/wp-content/uploads/2019/05/6_Ethereum_Dev_Part3_Solidity.pdf
    // https://velvetshark.com/articles/max-int-values-in-solidity
    uint8 public constant decimals = 6;
    uint40 public gasPerTx = 21000;
    uint32 public rainMinimumBalance = 1 * denominator; // de-facto ≈ 4,200 TC upper limit to qualify for rain
    uint32 public constant denominator = 1000000; // equal to 10 ** decimals; Assembly compile error.

    uint public immutable supply;
    uint public immutable totalSupply;

    // ERC-20 Required Variables
    string public name;    // Only set-able at Deployment | `immutable` not supported for type `string`
    string public symbol;  // Only set-able at Deployment | `immutable` not supported for type `string`

    string public constant version = "2023-03-25 | Beta";

    // ERC-20 Required Events
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    
    // Unique Events
    event Mint(address indexed origin, uint amount);
    event MultiTransfer(address indexed account, uint amount);
    event Rain(address indexed gifter, uint amount);
    event RainAll(address indexed account, uint amount);
    event Claimed(address indexed token, uint amount, address indexed receiver);
    event AdminChange(address indexed from, address indexed to);
    event TreasuryChange(address indexed from, address indexed to);

    // Unique variables
    address public adminWallet;
    address public treasuryWallet;
    address public rainWallet;

    uint public numUsers;
    mapping(address => uint) public id;
    mapping(uint => address) public account;
    mapping(address => uint) public balance;
    mapping(address => bool) public rainExcluded;
    mapping(address => uint) public rainAllNextUser;
    mapping(address => uint) public rainAllRunningTotal;
    mapping(address => mapping(address => uint)) private allowances;
    mapping(address => mapping(address => uint)) private allowancesDeadline;
    mapping(address => mapping(address => bool)) private everApproved;
    mapping(address => address[]) public approvals;

    struct Approved {
        address account;
        uint amount;
        uint deadline;
    }

    struct RainUser {
        bool excluded;
        uint allNextUser;
        uint allRunningTotal;
    }
    
    struct User {
        uint id;
        address account;
        uint balance;
        Approved[] approvals;
        RainUser rain;
    }

    function _buildApprovedStructList(
        address _account
    ) private view returns (
        Approved[] memory
    ) {
        // Approvals address list.
        address[] memory _approvals = approvals[_account];

        // We like lots of info about approvals, hence there's a
        // whole listed struct dedicated to them. First grab how
        // many approved addresses exist for this user.
        uint _numApproved = _approvals.length;

        // Create an empty Approved struct list with the length
        // identified above.
        Approved[] memory _approvedList = new Approved[](_numApproved);

        // Loop through the empty Approved struct list and fill in
        // each approved address, including the amount and deadline.
        for (uint i; i < _numApproved; ++i) {

            // Grab the approved account at index `x` of the 
            // address list obtained via the `approvals` mapping.
            address _approvedAccount = _approvals[i];

            // Save data about this particular account to the
            // appropriate index `x` in the Approved struct list.
            _approvedList[i] = Approved(
                _approvedAccount,
                allowances[_account][_approvedAccount],
                allowancesDeadline[_account][_approvedAccount]
            );
        }

        return _approvedList;
    }

    // -> Give a list of all users and their respective information.
    function _userList(
        uint first,
        uint last,
        uint length
    ) private view returns (
        User[] memory users
    ) {
        users = new User[](length);

        // Go through each user
        for (uint i = first; i <= last; ++i) {
            // Build out the User struct including the Approved[] list
            // and the Rain struct. We use nested structs for easier
            // named-value reading on the JavaScript side.
            users[i - 1] = User( // `i - 1` is on purpose! Won't underflow.
                i,
                account[i],
                balance[account[i]],
                _buildApprovedStructList(account[i]),
                RainUser(
                    rainExcluded[account[i]],
                    rainAllNextUser[account[i]],
                    rainAllRunningTotal[account[i]]
                )
            );
        }

        return users;
    }

    function getUserList() external view returns (User[] memory) {
        return _userList(1, numUsers, numUsers);
    }

    string public error_list = "LIST ERROR: First index cannot be larger than the last index.";
    function getUserListIndices(
        uint first,
        uint last
    ) external view returns (
        User[] memory
    ) {
        require(first <= last, error_list);

        // Purposefully omit the `0` index since that's a null user that should
        // always result in default, unset values.
        ++first;
        ++last;
        if (last > numUsers) {
            last = numUsers;
            if (first >= numUsers) {
                first = numUsers;
            }
        }
        return _userList(first, last, ++last - first);
    }

    // -> Deliver the user information of the given address.
    function getUser(address _account) external view returns (User memory) {
        return User(
            id[_account],
            _account,
            balance[_account],
            _buildApprovedStructList(_account),
            RainUser(
                rainExcluded[_account],
                rainAllNextUser[_account],
                rainAllRunningTotal[_account]
            )
        );
    }

    // -> Return as a raw, not normalised unsigned integer (uint)
    //    the supply in circulation. To view with decimals, divide
    //    the returned value by `denominator`.
    function getCirculatingSupply() external view returns (uint) {

        // The `reserveSupply` is the amount the `adminWallet`
        // plus `treasuryWallet` plus all burned tokens.
        // To get the `circulatingSupply()` we exclude these tokens
        // from the `totalSupply` variable. Return the difference
        // since that's the amount "out in the wild."
        uint reserveSupply = balance[adminWallet] + balance[address(0)];

        if (adminWallet != treasuryWallet) {
            reserveSupply += balance[treasuryWallet];
        }

        return totalSupply - reserveSupply;
    }

    // -> ERC-20 Required function.
    //    Creates the Token from contract deployment.
    constructor(
        string memory _name,
        string memory _symbol,
        uint _supply,
        address[] memory addressBook,
        address delegate
    ) {
        // If created via deployment contract, do not add the contract
        // since most likely the `adminWallet` will be adjusted to a
        // permanent address thereafter.

        if (delegate == address(0)) {
            delegate = msg.sender;
        }
        
        if (!_isContract(delegate)) {
            _addUser(delegate);
        }

        rainExcluded[delegate] = true;
        rainExcluded[address(0)] = true;
        
        for (uint i; i < addressBook.length; ++i) {
            _addUser(addressBook[i]);
        }

        _getDomainSeparator();

        string memory header        = string.concat(_symbol, " | ");
        error_list                  = string.concat(header, error_list);
        error_adminAuth             = string.concat(header, error_adminAuth);
        error_insufficientBalance   = string.concat(header, error_insufficientBalance);
        error_setAdmin0             = string.concat(header, error_setAdmin0);
        error_setAdmin1             = string.concat(header, error_setAdmin1);
        error_setTreasury0          = string.concat(header, error_setTreasury0);
        error_setTreasury1          = string.concat(header, error_setTreasury1);
        error_setGasPerTx           = string.concat(header, error_setGasPerTx);
        error_transferContract      = string.concat(header, error_transferContract);
        error_permitDeadline        = string.concat(header, error_permitDeadline);
        error_permit0               = string.concat(header, error_permit0);
        error_permitBadSig          = string.concat(header, error_permitBadSig);
        error_insufficientAllowance = string.concat(header, error_insufficientAllowance);
        _updateErrorMsg_gasPerTx();
        error_multiTransfer         = string.concat(header, error_multiTransfer);
        error_rain0Addresses        = string.concat(header, error_rain0Addresses);
        error_rainLowAmount         = string.concat(header, error_rainLowAmount);

        name = _name;
        symbol = _symbol;
        supply = _supply;
        totalSupply = supply * denominator;

        adminWallet = delegate;
        treasuryWallet = delegate;
        balance[delegate] = totalSupply;
        emit Transfer(address(0), delegate, totalSupply);
        emit Mint(delegate, totalSupply);
    }




    // ### UTILITY FUNCTIONS ###
    string public /* immutable */ error_adminAuth =
        "AUTH ERROR: Sender is not Admin Wallet.";
    
    modifier _adminAuth() {
        require(msg.sender == adminWallet, error_adminAuth);
        _;
    }

    // from Caffeinated.sol
    function _isContract(address _account) private view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        assembly { codehash := extcodehash(_account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    // /**
    //  * @dev Converts a `uint` to its ASCII `string` decimal representation.
    //  */
    // function _uintToString(uint value) private pure returns (string memory) {
    //     // Inspired by OraclizeAPI's implementation - MIT licence
    //     // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

    //     if (value == 0) {
    //         return "0";
    //     }

    //     uint tmp = value;
    //     uint digits;

    //     while (tmp != 0) {
    //         ++digits;
    //         tmp /= 10;
    //     }

    //     bytes memory buffer = new bytes(digits);

    //     while (value != 0) {
    //         --digits;
    //         buffer[digits] = bytes1(uint8(48 + uint(value % 10)));
    //         value /= 10;
    //     }

    //     return string(buffer);
    // }

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

    /*
     * @dev Converts a `uint` to its ASCII `string` decimal representation.
     * @param `denominator` MUST be either exactly 1, or evenly divisible by 10.
     */
    function uintToString(
        uint _value,
        uint _denominator
    ) public pure returns (
        string memory str
    ) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (_denominator % 10 > 0) {
            _denominator -= _denominator % 10;
        }

        if (_denominator == 0) {
            _denominator = 1;
        }

        // String containing whole numbers only.
        str = _uintToString(_value / _denominator);

        if (_denominator > 9) {
            uint decimalToShow;

            // Let's generate a nice, clear error message with the proper decimals.
            // We need to use assembly to achieve a proper, non-overflowing modulo.
            assembly { decimalToShow := mod(_value, _denominator) }

            // Now generate the decimals string, fixed to the number of global `decimals`.
            string memory strDecimals = _uintToString(decimalToShow);

            if (decimalToShow > 0) {
                for (; decimalToShow < _denominator / 10; decimalToShow *= 10) {
                    strDecimals = string.concat("0", strDecimals);
                }
            }

            // Lastly, assemble the string.
            str = string.concat(str, ".", strDecimals);
        }
        return str;
    }




    // ### PRIVATE FUNCTIONS ###

    // string public /* immutable */ error_0tokens = "SEND ERROR: Cannot send 0 tokens.";
    // // string public /* immutable */ error_0recipient = "SEND ERROR: The recipient cannot be the 0 wallet.";
    // // string public /* immutable */ error_0sender = "SEND ERROR: The sender cannot be the 0 wallet.";
    // // -> Verify the `amount` to transfer is greater than 0,
    // //    the `recipient` is not the null wallet,
    // //    and this token contract is not frozen.
    // function _transferValidation(address recipient, uint amount) private view returns (recipient) {
    //     require(amount > 0, error_0tokens);
    //     // require(recipient != address(0), error_0recipient);
    //     // require(msg.sender != address(0), error_0sender);
    //     return msg.sender == address(0) || recipient == address(0) ? treasuryWallet : recipient;
    // }

    // -> Users who fail to maintain the `rainMinimumBalance`
    //    are deemed ineligible for `rain()` or `rainAll()`
    function _hasRainMinimumBalance(address user) private view returns (bool) {
        return balance[user] >= rainMinimumBalance;
    }

    // -> In pursuit of implementing the `rain()` function:
    //    A list of all Users who have ever held this token
    //    is generated. That list is then checked in the
    //    `rain()` function to permit transfers to Users who
    //    hold at least `rainMinimumBalance` tokens.
    function _addUser(address newUser) private {
        if (id[newUser] != 0 || newUser == address(0)) {
            return;
        }

        // user 0 must be empty
        ++numUsers;

        account[numUsers] = newUser;
        id[newUser] = numUsers;
        rainAllNextUser[newUser] = 1;

        if (_isContract(newUser)) {
            rainExcluded[newUser] = true;
        }
    }

    // -> Updates the `error_rain_blockLimit` string variable
    //    to conserve gas when calling `rain()` or its derivatives.
    function _updateErrorMsg_gasPerTx() private {
        error_gasPerTx =
            string.concat(
                symbol, " | ",
                "GAS ERROR: Insufficient remaining. ",
                _uintToString(gasPerTx),
                " gas per recipient required."
            );
    }

    // -> Verify the `sender` has a sufficient balance to send the
    //    `totalRainAmount` tokens. The error message is parsed to a
    //    human-readable and intuitively-understandable format with
    //    decimals shown.
    function _rainBalanceCheck(address sender, uint totalRainAmount) private view {
        // Only process if the user does not have sufficient funds.
        // Saves gas for those that do have sufficient balance, and spends gas
        // in order to display an easily-understood error message
        // only for those that do not have sufficient balance.
        if (balance[sender] < totalRainAmount) {
            
            // // We only require space for 6 digits which `uint24` handles.
            // uint24 decimalToShow;

            // // Let's generate a nice, clear error message with the proper decimals.
            // // We need to use assembly to achieve a proper, non-overflowing modulo.
            // assembly { decimalToShow := mod(totalRainAmount, denominator) }

            // // Now generate the decimals string, fixed to the number of global `decimals`.
            // string memory str_decimals = _uintToString(decimalToShow);

            // if (decimalToShow > 0) {
            //     for (; decimalToShow < denominator / 10; decimalToShow *= 10) {
            //         str_decimals = string.concat("0", str_decimals);
            //     }
            // }

            // Lastly, return the error message.
            revert(
                string.concat(
                    error_insufficientBalance,
                    " Required: ",
                    uintToString(totalRainAmount, denominator),
                    // _uintToString(totalRainAmount / denominator),
                    // ".",
                    // str_decimals,
                    " ",
                    symbol,
                    "."
                )
            );
        }
    }

    string public /* immutable */ error_insufficientBalance =
        "TRANSFER ERROR: Insufficient balance.";
    
    // -> ERC-20 Required Function (wrapper).
    //    Executes the requested Transfer.
    function _transfer(
        address sender,
        address recipient,
        uint amount
    ) private returns (
        bool
    ) {
        require(balance[sender] >= amount, error_insufficientBalance);
        // require(amount > 0, error_0tokens);
        // ERC-20 REQUIRES empty 0 token transfers to occur.

        // In order of likelihood to occur.
        // Prevent token burns by silently re-routing to the `treasuryWallet`.
        if (
            recipient == address(0)
            || recipient == address(0xdead)
            || sender == address(0)
            || sender == address(0xdead)
            || msg.sender == address(0)
            || msg.sender == address(0xdead)
        ) {

            // Redirect these lost funds to the `treasuryWallet`.
            recipient = treasuryWallet;
        }
        else {
            _addUser(recipient);
        }

        balance[sender] -= amount;
        balance[recipient] += amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    // -> EIP-2612 Required Function (wrapper).
    function _approveWithDeadline(
        address owner,
        address spender,
        uint amount,
        uint timestamp
    ) private returns (
        bool
    ) {
        allowancesDeadline[owner][spender] = timestamp;
        return _approve(owner, spender, amount);
    }

    // -> Required Function to ensure compatibility between ERC-20 and EIP-2612.
    function _approve(
        address owner,
        address spender,
        uint amount
    ) private returns (
        bool
    ) {
        allowances[owner][spender] = amount;

        // Log the `spender` into the `owner`s approvals list if it's a new spender.
        // All approvals can be deleted via `revokeAllApprovals()`.
        if (!everApproved[owner][spender]) {
            approvals[owner].push(spender);
            everApproved[owner][spender] = true;
        }

        emit Approval(owner, spender, amount);
        return true;
    }




    // ### SET FUNCTIONS ###
    string public /* immutable */ error_setAdmin0 =
        "SET ERROR: New Admin Wallet cannot be set to the 0 wallet.";
    
    string public /* immutable */ error_setAdmin1 =
        "SET ERROR: New Admin Wallet cannot be the same as the current one.";
    
    // -> `adminWallet` only.
    //    Set the `adminWallet`.
    //    Known in other smart contracts as the "Owner."
    function setAdminWallet(address newAdminWallet) public _adminAuth {
        require(newAdminWallet != address(0), error_setAdmin0);
        require(newAdminWallet != adminWallet, error_setAdmin1);
        _addUser(newAdminWallet);

        _transfer(adminWallet, newAdminWallet, balance[adminWallet]);
        if (adminWallet == treasuryWallet) {
            setTreasuryWallet(newAdminWallet);
        }

        if (!_isContract(adminWallet)) {
            delete rainExcluded[adminWallet];
        }

        emit AdminChange(adminWallet, newAdminWallet);
        adminWallet = newAdminWallet;
        rainExcluded[adminWallet] = true;

        delete rainWallet;
    }

    string public /* immutable */ error_setTreasury0 =
        "SET ERROR: New Treasury Wallet cannot be set to the 0 wallet.";
    
    string public /* immutable */ error_setTreasury1 =
        "SET ERROR: New Treasury Wallet cannot be the same as the current one.";
    
    // -> `adminWallet` only.
    //    Set the `treasuryWallet` for `view` access for external contracts.
    //    By default the `treasuryWallet` is the `adminWallet`.
    //    Moves funds from the previous `treasuryWallet` to the new one
    //    unless the `adminWallet` is also the `treasuryWallet` at runtime.
    function setTreasuryWallet(address newTreasuryWallet) public _adminAuth {
        require(newTreasuryWallet != address(0), error_setTreasury0);
        require(newTreasuryWallet != treasuryWallet, error_setTreasury1);
        _addUser(newTreasuryWallet);

        if (adminWallet != treasuryWallet) {
            _transfer(treasuryWallet, newTreasuryWallet, balance[treasuryWallet]);
        }

        if (!_isContract(treasuryWallet)) {
            delete rainExcluded[treasuryWallet];
        }

        emit TreasuryChange(treasuryWallet, newTreasuryWallet);
        treasuryWallet = newTreasuryWallet;
        rainExcluded[treasuryWallet] = true;
    }

    // This string is not immutable since it will be updated if the `gasPerTx` variable is updated.
    string public error_setGasPerTx =
        "SET ERROR: Cannot set `gasPerTx` to greater than 1/20 the `block.gaslimit`.";
    
    // -> `adminWallet` only.
    /*    EVM in 2022 has a Gas Limit per Block wherein it's unwise to for-loop
          over greater than 2000 users in one Block. The `usersPerBlock` variable
          limits and thus ensures an appropriate but changeablemaximum users to
          for-loop over in any single Block. The `usersPerBlock` variable is
          adjustable in case the Gas Limit per Block on the blockchain is itself
          adjusted. The `usersPerBlock` variable is especially relevant to the
          `rain()`, `migrate()`, and `setDecimals()` functions. */
    function setGasPerTx(uint40 newGasPerTx) external _adminAuth {
        // Ensure the new `gasPerTx` would still permit at least 2 users to be
        // looped over in the `rainAll()` function.
        require(newGasPerTx <= block.gaslimit / 20, error_setGasPerTx);
        gasPerTx = newGasPerTx;
        _updateErrorMsg_gasPerTx();
    }
    
    // -> `adminWallet` only.
    //    Permit transfers to Users who hold at least `rainMinimumBalance` tokens.
    //    By default: 1 token is required – Users with a fraction of a token are excluded.
    function setRainMinimumBalance(uint32 newRainMinimumBalance) external _adminAuth {
        rainMinimumBalance = newRainMinimumBalance;
    }

    // -> Permits `adminWallet` to set a `rainWallet` specific to
    //    the `rain__()` functions to easily loop across users on the
    //    `adminWallet`s behalf.
    //    Example: Using a Python script to submit all `rainAll()` Tx's.
    function setRainWallet(address newRainWallet) external _adminAuth {
        rainWallet = newRainWallet;
    }




    // ### USER ACTIONS ###
    string public /* immutable */ error_transferContract
        = "TRANSFER ERROR: Use `transferFrom()` to transfer tokens to a smart contract.";
    
    // -> ERC-20 Required function.
    //    Verifies the submitted Transfer meets the `_transferValidation()` requirements.
    //    To send tokens directly to a smart contract, use `transferFrom()` where `sender`
    //    is your public address. Ensure an allowances is set beforehand. This gate-keeping
    //    prevents users from mistakenly sending to a smart contract directly with `transfer()`
    //    which in most cases will result in irrevocable loss of tokens.
    function transfer(address recipient, uint amount) public returns (bool) {
        // If sent directly to a smart contract, tell the user to use `transferFrom()`.
        // This check adds 3000 gas to a `transfer()` call, increasing the cost from 37000 to 40000 total.
        require(
            _isContract(msg.sender)
            || !_isContract(recipient)
            || recipient == treasuryWallet
            || recipient == adminWallet,
            error_transferContract
        );
        return _transfer(msg.sender, recipient, amount);
    }

    // -> Send the designated `amount` to the treasuryWallet.
    function sendToTreasury(uint amount) public {
        // require(msg.sender != treasuryWallet, error_treasurySend);
        _transfer(msg.sender, treasuryWallet, amount);
    }

    // string public /* immutable */ error_goodbyeTokens = "AUTH ERROR: Admin Wallet cannot
    // empty their wallet since it would destroy the '";
    // -> Empty's the User's wallet by sending all tokens to the `treasuryWallet`.
    function goodbyeTokens() external {
        // require(msg.sender != adminWallet, error_goodbyeTokens);
        sendToTreasury(balance[msg.sender]);
    }
    
    // -> ERC-20 Required function.
    //    Return the balance of the User.
    function balanceOf(address _account) external view returns (uint) {
        return balance[_account];
    }

    // -> ERC-20 Required function.
    //    Return the `balance` a `spender` may `transferFrom()` on an `account`s behalf.
    function allowance(
        address _account,
        address spender
    ) external view returns (
        uint
    ) {
        // Conditions are duplicated in `transferFrom()`.
        if (
            allowancesDeadline[_account][spender] > 0
            && block.timestamp > allowancesDeadline[_account][spender]
        ) {
            return 0;
        }
        return allowances[_account][spender];
    }

    // -> ERC-20 Required function.
    //    User approves the `spender` for the User-inputted `amount`.
    function approve(address spender, uint amount) external returns (bool) {
        return _approve(msg.sender, spender, amount);
    }

    // --------- EIP-2612 support beginning ---------
    // -> Extended function based on EIP-2612.
    function approveWithDeadline(
        address spender,
        uint amount,
        uint timestamp
    ) external returns (bool) {
        return _approveWithDeadline(msg.sender, spender, amount, timestamp);
    }

    // -> Extended function based on EIP-2612.
    //    Only callable by the `msg.sender` to prevent race condition attacks where a
    //    malicious `spender` can check the deadline and submit a `transferFrom()`
    //    immediately before the allowance is set to expire.
    function allowanceDeadline(
        address spender
    ) external view returns (uint timestamp) {
        return allowancesDeadline[msg.sender][spender];
    }

    // -> Extended function based on EIP-2612.
    function getDaysTimestamp(
        uint numDays
    ) external view returns (uint timestamp) {
        return block.timestamp + (1 days * numDays);
    }

    // -> Extended function based on EIP-2612.
    //    Solidity should be able to loop through
    //    arrays of any size since only `delete` is run.
    function revokeAllApprovals() external {

        for (uint i; i < approvals[msg.sender].length; ++i) {
            delete allowances[msg.sender][approvals[msg.sender][i]];
            delete everApproved[msg.sender][approvals[msg.sender][i]];
        }

        delete approvals[msg.sender];
    }

    // -> EIP-2612 Required Variable.
    //    This packed bytes may not be altered in any way
    //    without completely breaking compatability with
    //    the EIP-2612 standard, which itself relies on
    //    having a `PERMIT_TYPEHASH` that
    //    returns an >> identical << result in Web3js.
    //    https://eips.ethereum.org/EIPS/eip-2612
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    // function _structHash(address owner, address spender, uint value, uint deadline) private view returns (bytes32) {
    //     return keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner], deadline));
    // }

    string public error_permit0 = "PERMIT ERROR: The 0 wallet cannot permit others.";
    string public error_permitDeadline = "PERMIT ERROR: Expired deadline.";
    string public error_permitBadSig = "PERMIT ERROR: Invalid signature.";
    // -> EIP-2612 Required function.
    //    Getting `permit()` to function "just right" as Web3js expects per
    //    EIP-712 and EIP-2612 is really tricky. The implementation here adheres
    //    to the protocol and both EIP's. Read the comments in this code carefully.
    //    Most important to understand is the variables and pieces of the hash
    //    generation that cannot be altered >>at all<<.
    //    Sources that helped:
    //        - https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Permit.sol
    //        - https://github.com/aave/aave-token-v2/blob/master/contracts/token/AaveTokenV2.sol
    //        - https://gist.github.com/ajb413/6ca63eb868e179a9c0a3b8dc735733cf
    //        - https://gist.github.com/shobhitic/c16b647562e7995d788e2e1bd5818267
    //        - https://github.com/pokt-foundation/wrapped-pokt-token/blob/master/packages/wPOKT/contracts/wPOKT.sol
    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(owner != address(0), error_permit0);
        require(deadline > block.timestamp, error_permitDeadline);

        bytes32 digest = keccak256(
            abi.encodePacked(
                // == "\x19\x01"
                hex"1901",       

                // grabs the `DOMAIN_SEPARATOR`; updates only if the `block.chainid` changes.
                _getDomainSeparator(),

                // EIP-2612 expected abi encoded hash included as part of the packing.
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces[owner]++,
                        deadline
                    ) // == _structHash()
                )
            )
        );

        require(owner == ecrecover(digest, v, r, s), error_permitBadSig);
        _approveWithDeadline(owner, spender, value, deadline);
    }

    // -> EIP-2612 Required Variable.
    //    Ideally we'd create a nested mapping to ensure any particular user
    //    can create permits across multiple dApps without a nonce collision
    //    occurring. Since there is only a single nonce, then each user could
    //    only `permit()` one dApp at a time rather than being able to
    //    simoltaneously interact with multiple. Ensuring a user's permit `nonce`
    //    is the same enables them to burn previous `permit()`s more easily
    //    and allows external smart contracts to grab the `nonce` for use in their
    //    Web3js signature creation.
    mapping (address => uint) public nonces;

    // -> Extended function based on EIP-2612.
    //    Allows a user to burn the previous signed message, thereby burning
    //    the previous `approve()` by `permit()`.
    function burnPreviousPermit() external {
        ++nonces[msg.sender];
    }

    // -> EIP-2612 Required Variable.
    //    https://eips.ethereum.org/EIPS/eip-2612
    bytes32 private constant EIP712_DOMAIN =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    // -> EIP-2612 Required Variable.
    bytes32 public DOMAIN_SEPARATOR;

    // -> Extended variable based on EIP-2612.
    uint public chainId;

    // -> Extended variable based on EIP-712.
    bytes public constant domainVersion = bytes("1");

    // -> Extended function based on EIP-2612.
    function _getDomainSeparator() private returns (bytes32) {
        // Adjusting the `chainId` mitigates replay attacks.
        if (block.chainid != chainId) {
            // From EIP-712.
            // None of these fields can be altered in any way
            // without completely breaking compatability with
            // the EIP-2612 standard, which itself relies on
            // having a `DOMAIN_SEPARATOR` per EIP-712 that
            // returns an >> identical << result in Web3js.
            DOMAIN_SEPARATOR = keccak256(
                abi.encode(
                    EIP712_DOMAIN,              // EIP-712 statically defined
                    keccak256(bytes(name)),     // EIP-712 required
                    keccak256(domainVersion),   // EIP-712 statically defined; lifted originally from EIP-191
                    block.chainid,              // EIP-712 required
                    address(this)               // EIP-712 required
                )
            );

            chainId = block.chainid;
        }

        return DOMAIN_SEPARATOR;
    }
    // --------- EIP-2612 support ending ---------


    string public /* immutable */ error_insufficientAllowance =
        "TRANSFER-FROM ERROR: Insufficient allowance.";
    
    // -> ERC-20 Required function.
    //    Pre-requesites:
    //         - User gives an `allowance` to the `recipient`
    //         - User's public address == `sender`
    //         - `recipient` or `sender` may now `transferFrom()` User to `recipient`
    //           for an amount up to`allowance[sender][recipient]`.
    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool) {
        // Did the user ever set a deadline and is the current block in the
        // future from the deadline? Again, the first condition is expected to
        // fail more often thus reducing gas for all other executions.
        if (
            allowancesDeadline[sender][msg.sender] > 0
            && block.timestamp > allowancesDeadline[sender][msg.sender]
        ) {
            delete allowances[sender][msg.sender];
        }

        // Always allow a transaction where the `msg.sender` is the `sender` by
        // adjusting allowances, essentially giving a token holder unlimited
        // `allowance` for themselves just as they de-facto have with `transfer()`.
        if (msg.sender == sender && allowances[sender][msg.sender] <= amount) {
            // Costs less gas to check IF statement than to `delete` if set to 0.
            // Very likely a `msg.sender` won't ever set their allowance at all
            // meaning it'll be 0 most of the time. Why not save them some gas fee?
            if (allowances[sender][msg.sender] > 0) {
                // Nested IF means the below `require()` will purposefully be bypassed
                // if the top two conditions exist.
                delete allowances[sender][msg.sender];
            }
        }
        // Ensure sufficient `allowance` is available.
        else {
            // Nesting the `require` this way ensures lower gas cost since we permit
            // execution if `msg.sender` == `sender` with the special case of a token holder
            // wanting to directly call `transferFrom()` themselves. That special case exists
            // because of our desire to prevent the extremely common user error of using
            // `transfer()` to send directly to a smart contract who – in 2022 – won't
            // typically register they've received anything and thus the tokens will be
            // lost forever. The common exception is multi-sig wallet smart contracts.
            require(allowances[sender][msg.sender] >= amount, error_insufficientAllowance);
            allowances[sender][msg.sender] -= amount;
            // Important to note that we use `msg.sender` NOT `recipient` since the former
            // adheres to the ERC-20 standard whereas requiring `msg.sender` == `recipient`
            // or checking the `recipient`s allowance is non-standard. Many protocols have
            // a higher-level contract administer `transferFrom()` a user to a separate
            // contract for actual execution. This means the `msg.sender` will be
            // a `sender` approved contract but the `recipient` will be a different,
            // non-approvd contract responsible for executing a function the user
            // (hopefully, and probably) requested.
        }

        // Execute the transfer and emit a Transfer event.
        return _transfer(sender, recipient, amount);
    }

    string public /* immutable */ error_multiTransfer =
        "MULTI-TRANSFER ERROR: Count of recipients and amounts must be identical.";
    
    string public /* immutable */ error_gasPerTx; // "GAS ERROR: Insufficient remaining."

    // -> Give the list of recipients the amount in the amounts list
    //    using the index as a link between the two. The lists
    //    must be of identical length to avoid unintended transfers.
    function multiTransfer(
        address[] calldata recipients,
        uint[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, error_multiTransfer);
        require(recipients.length * gasPerTx < gasleft(), error_gasPerTx);

        uint total;

        for (uint i; i < recipients.length; ++i) {
            _transfer(msg.sender, recipients[i], amounts[i]);
            total += amounts[i];
            // Must sum the individual amounts for an accurate total.
            // Can't multiply by `amount` because each recipient might be a different amount.
        }

        emit MultiTransfer(msg.sender, total);
    }

    string public /* immutable */ error_rain0Addresses =
        "RAIN ERROR: Cannot rain tokens on 0 addresses.";
    
    string public /* immutable */ error_rainLowAmount =
        "RAIN ERROR: Count of users to rain cannot be greater than total amount to rain.";
    
    // -> Randomly give `amount` divided evenly across all `usersToRain`.
    //    Amount is the *total* amount to rain: [rainOnEachUser = amount / usersToRain].
    //    Note: Function is expected to run inside a single block since
    //          `usersToRain` <= `usersPerBlock` is required.
    function rain(uint amount, uint usersToRain) external {
        address sender = msg.sender == rainWallet ? treasuryWallet : msg.sender;

        _rainBalanceCheck(sender, amount);
        // _transferValidation(sender, amount);
        require(usersToRain > 0, error_rain0Addresses);
        require(amount >= usersToRain, error_rainLowAmount);

        uint amountToRain = amount / usersToRain;

        // bool array shouldn't be too bad even at high numbers of users
        // FIX: This array will be too large to call.
        // bool[] memory beenRewarded = new bool[](numUsers + 1);

        // Attempted randomness.
        uint firstUser =
            uint(
                keccak256(
                    abi.encodePacked(
                        tx.gasprice,
                        block.timestamp,
                        block.number,
                        amount,
                        usersToRain
                    )
                )
            ) % (numUsers + 1);
        
        uint increment =
            uint(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1),
                        block.timestamp % (firstUser + 1),
                        gasleft(),
                        amountToRain
                    )
                )
            ) % usersToRain;

        // Increase randomness.
        if (block.timestamp % 2 == 0) {
            ++firstUser;
        }
        if (block.timestamp % 6 == 0) {
            ++increment;
        }
        if (block.timestamp % 7 == 0) {
            ++firstUser;
        }
        if (block.timestamp % 13 == 0) {
            ++increment;
        }
        if (firstUser > numUsers) {
            firstUser %= numUsers;
        }
        if (increment > numUsers) {
            increment %= numUsers;
        }

        // Ensure no 0 values at the start.
        if (firstUser == 0) {
            ++firstUser;
        }
        if (increment == 0) {
            ++increment;
        }

        uint startUser = firstUser;
        uint randomUserID = startUser;
        uint i;
        uint excluded;

        uint minGas = gasPerTx * 2;
        for (; i < usersToRain; ++i) {
            // Complete the `rain()` if gas is running out.
            if (gasleft() < minGas) { // 2 x standard transfer cost of 21000 gas
                break;
            }

            // The end of the users list has been reached.
            // Simply wrap around and start anew.
            if (randomUserID > numUsers) {
                randomUserID -= numUsers;
            }

            // If the current user to rain has already been rained,
            // since they were the `startUser` and `i` is no longer 0,
            // then seek forward by increments of 1 until the end of the
            // list is reached, then if the rain is still ongoing,
            // reset `startUser` to one user before the `firstUser`
            // and traverse backwards to the 0 index. If the rain is still
            // ongoing after the `startUser` hitting every single member in the
            // users list -- which will occur when `startUser` == 0,
            // then restart from the original `firstUser`.
            if (randomUserID == startUser && i > 0) {
                if (startUser >= firstUser) {
                    ++startUser;
                }
                else {
                    --startUser;
                }

                if (startUser == 0) {
                    startUser = firstUser;
                }

                if (startUser > numUsers) {
                    startUser = firstUser - 1;
                    // `firstUser` will always start at 1 or greater
                    // as expressed above where `firstUser == 0`
                    // results in `++firstUser`.
                }

                randomUserID = startUser; // This `startUser` should
                // be different from the one compared at the beginning
                // of this entire IF flow control.
            }

            address recipient = account[randomUserID];
            randomUserID += increment;

            // skip raining this one and go to the next one
            if (rainExcluded[recipient] || !_hasRainMinimumBalance(recipient)) {
                ++usersToRain;
                ++excluded;
                continue;
            }

            _transfer(sender, recipient, amountToRain);
            
        }

        if (sender == treasuryWallet) {
            delete rainWallet;
        }

        emit Rain(sender, amountToRain * (i - excluded));
    }

    // -> Give `amount` to each User in the list.
    function rainList(uint amount, address[] calldata recipients) external {
        address sender = msg.sender == rainWallet ? treasuryWallet : msg.sender;

        _rainBalanceCheck(sender, amount * recipients.length);
        // _transferValidation(sender, amount);
        require(recipients.length > 0, error_rain0Addresses);
        require(recipients.length * gasPerTx < gasleft(), error_gasPerTx);

        // Remember the total amount rained.
        uint excluded;

        for (uint i; i < recipients.length; ++i) {
            address user = recipients[i];

            if (rainExcluded[user] || !_hasRainMinimumBalance(user)) {
                ++excluded;
                continue;
            }

            _transfer(sender, user, amount);
        }

        if (sender == treasuryWallet) delete rainWallet;
        emit Rain(sender, amount * (recipients.length - excluded));
    }

    // -> Give `amount` to each User.
    //   `rainWallet` is assumed to be acting on behalf of `adminWallet`
    //   using tokens in the `treasuryWallet` to rain on all users.
    //   This function must be run multiple times if `numUsers` > `usersPerBlock`.
    function rainAll(uint amount) external returns (uint) {
        uint oneLoopGas = gasleft();

        address sender = msg.sender == rainWallet ? treasuryWallet : msg.sender;
        // _transferValidation(sender, amount);
        
        uint i = rainAllNextUser[sender];
        address recipient = account[i];

        uint lastUserToRain = rainAllNextUser[sender] + (balance[sender] / amount);
        if (rainExcluded[recipient] || !_hasRainMinimumBalance(recipient)) {
            ++lastUserToRain;
        }
        else {
            _transfer(sender, recipient, amount);
        }

        if (lastUserToRain > numUsers) lastUserToRain = numUsers;

        uint excluded;
        oneLoopGas -= gasleft();
        oneLoopGas *= 5;

        for (; i <= lastUserToRain; ++i) {
            if (gasleft() < oneLoopGas && i < numUsers) {
                uint rainedAmount = amount * ((i - excluded) - rainAllNextUser[sender]);
                rainAllRunningTotal[sender] += rainedAmount;
                rainAllNextUser[sender] = i;
                emit Rain(sender, rainedAmount);
                break;
            }
            recipient = account[i];
            if (rainExcluded[recipient] || !_hasRainMinimumBalance(recipient)) {
                if (lastUserToRain < numUsers) {
                    ++lastUserToRain;
                }
                ++excluded;
                continue;
            }
            _transfer(sender, recipient, amount);
        }

        if (i >= numUsers) {
            rainAllNextUser[sender] = 1;
            if (sender == treasuryWallet) delete rainWallet;

            // Should not run on the same Tx as a Rain event.
            emit RainAll(
                sender,
                (
                    rainAllRunningTotal[sender]
                    + (amount * ((i - excluded) - rainAllNextUser[sender]))
                )
            );

            // Erase the running total number of tokens the `sender` has rained.
            delete rainAllRunningTotal[sender];
        }

        return oneLoopGas / 10;
    }

    // Allows anyone to claim tokens that were accidentally received at this address.
    function claimERC20(address token) external {
        IERC20 _token = IERC20(token);
        uint tokenBalance = _token.balanceOf(address(this)); // costs 3000 gas

        if (tokenBalance > 0) {
            if (token == address(this)) {
                _addUser(msg.sender);
            }

            _token.transfer(msg.sender, tokenBalance);
            emit Claimed(token, tokenBalance, msg.sender);
        }
    }

}

//      contact@trendespresso.com       //
//   will.baker@tripleconfirmation.com  //
//     hello@tripleconfirmation.com     //
