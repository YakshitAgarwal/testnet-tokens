// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error NotOwner();
error NotOperator();
error Paused();
error Blacklisted();
error InvalidAddress();
error TransferFailed();
error CooldownActive();
error InsufficientBalance();
error AboveMaxPayout();
error BelowMinPayout();
error AlreadyOperator();
error NotAnOperator();
error LastOperator();
error AlreadyBlacklisted();
error NotBlacklisted();

/*//////////////////////////////////////////////////////////////
                        CONTRACT
//////////////////////////////////////////////////////////////*/

contract TestnetTokens {

    /*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public owner;
    bool public paused;

    uint256 public operatorCount;
    uint256 public maxAllowedPayout = 0.5 ether;
    uint256 public minAllowedPayout = 0.01 ether;
    uint256 public cooldownPeriod = 1 days;
    uint256 public refillThreshold = 1 ether;

    mapping(address => uint256) public lastRequestTime;
    mapping(address => bool) public operators;
    mapping(address => bool) public blacklistedAddresses;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event DepositReceived(address indexed from, uint256 amount);
    event TokenTransfer(address indexed to, uint256 amount);
    event OperatorAdded(address indexed addr);
    event OperatorRemoved(address indexed addr);
    event AddressBlacklisted(address indexed addr);
    event AddressWhitelisted(address indexed addr);
    event CooldownPeriodChanged(uint256 newCooldown);
    event MaxAllowedPayoutChanged(uint256 newMax);
    event MinAllowedPayoutChanged(uint256 newMin);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event FaucetPaused();
    event FaucetResumed();
    event RefillRequested(uint256 balance);
    event RefillThresholdChanged(uint256 threshold);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (!operators[msg.sender]) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        owner = msg.sender;
        operators[msg.sender] = true;
        operatorCount = 1;
    }

    /*//////////////////////////////////////////////////////////////
                        RECEIVE FUNCTION
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        emit DepositReceived(msg.sender, msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                        FAUCET FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transferToken(address to, uint256 amount)
        external
        onlyOperator
        whenNotPaused
    {
        if (blacklistedAddresses[to]) revert Blacklisted();
        if (to == address(0) || to == address(this) || to == owner)
            revert InvalidAddress();

        if (amount > maxAllowedPayout) revert AboveMaxPayout();
        if (amount < minAllowedPayout) revert BelowMinPayout();

        uint256 lastRequest = lastRequestTime[to];

        if (block.timestamp < lastRequest + cooldownPeriod)
            revert CooldownActive();

        if (address(this).balance < amount)
            revert InsufficientBalance();

        lastRequestTime[to] = block.timestamp;

        (bool success,) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit TokenTransfer(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function viewBalance()
        external
        view
        onlyOperator
        returns (uint256)
    {
        return address(this).balance;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN CONTROL
    //////////////////////////////////////////////////////////////*/

    function pauseFaucet() external onlyOwner {
        paused = true;
        emit FaucetPaused();
    }

    function resumeFaucet() external onlyOwner {
        paused = false;
        emit FaucetResumed();
    }

    function changeMaxAllowedPayout(uint256 newMax)
        external
        onlyOwner
    {
        maxAllowedPayout = newMax;
        emit MaxAllowedPayoutChanged(newMax);
    }

    function changeMinAllowedPayout(uint256 newMin)
        external
        onlyOwner
    {
        minAllowedPayout = newMin;
        emit MinAllowedPayoutChanged(newMin);
    }

    function changeCooldownPeriod(uint256 newCooldown)
        external
        onlyOwner
    {
        cooldownPeriod = newCooldown;
        emit CooldownPeriodChanged(newCooldown);
    }

    function changeRefillThreshold(uint256 threshold)
        external
        onlyOwner
    {
        refillThreshold = threshold;
        emit RefillThresholdChanged(threshold);
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addOperator(address operator)
        external
        onlyOwner
    {
        if (operator == address(0)) revert InvalidAddress();
        if (operators[operator]) revert AlreadyOperator();

        operators[operator] = true;
        operatorCount++;

        emit OperatorAdded(operator);
    }

    function removeOperator(address operator)
        external
        onlyOwner
    {
        if (!operators[operator]) revert NotAnOperator();
        if (operatorCount == 1) revert LastOperator();

        operators[operator] = false;
        operatorCount--;

        emit OperatorRemoved(operator);
    }

    /*//////////////////////////////////////////////////////////////
                        BLACKLIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function blacklistAddress(address addr)
        external
        onlyOperator
    {
        if (addr == owner || operators[addr])
            revert InvalidAddress();

        if (blacklistedAddresses[addr])
            revert AlreadyBlacklisted();

        blacklistedAddresses[addr] = true;

        emit AddressBlacklisted(addr);
    }

    function whitelistAddress(address addr)
        external
        onlyOperator
    {
        if (!blacklistedAddresses[addr])
            revert NotBlacklisted();

        blacklistedAddresses[addr] = false;

        emit AddressWhitelisted(addr);
    }

    /*//////////////////////////////////////////////////////////////
                        TREASURY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function withdrawAll()
        external
        onlyOwner
    {
        uint256 balance = address(this).balance;

        (bool success,) = owner.call{value: balance}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(owner, balance);
    }

    function withdrawSome(uint256 amount)
        external
        onlyOwner
    {
        if (amount > address(this).balance)
            revert InsufficientBalance();

        (bool success,) = owner.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(owner, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNERSHIP MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner)
        external
        onlyOwner
    {
        if (newOwner == address(0))
            revert InvalidAddress();

        if (blacklistedAddresses[newOwner])
            revert Blacklisted();

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                        REFILL SIGNAL
    //////////////////////////////////////////////////////////////*/

    function refillFaucet()
        external
        onlyOperator
    {
        if (address(this).balance <= refillThreshold)
            emit RefillRequested(address(this).balance);
    }
}