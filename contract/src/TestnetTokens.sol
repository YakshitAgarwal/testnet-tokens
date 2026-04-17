// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract TestnetTokens{
    address public owner;
    bool public paused;

    uint256 public cooldownPeriod = 1 days;
    uint256 public refillThreshold = 1 ether;

    mapping(address => uint256) public lastRequestTime;
    mapping(address => uint256) public requestCount;
    mapping(address => bool) public blacklistAddresses;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    receive() external payable {}

    function claimTokens(address _to) external onlyOwner {
        require(!paused, "Contract is paused");
        require(_to != address(0), "Invalid address");
        require(_to != owner, "Owner cannot claim tokens");
        require(_to != address(this), "Contract cannot claim tokens");
        require(!blacklistAddresses[_to], "Address is blacklisted");
        uint256 currentTime = block.timestamp;
        require(currentTime - lastRequestTime[_to] >= cooldownPeriod, "Cooldown period not over");

        lastRequestTime[_to] = currentTime;
        requestCount[_to]++;

        (bool success, ) = _to.call{value: 0.01 ether}("");
        require(success, "Failed to send tokens");
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function changeCooldownPeriod(uint256 _cooldownPeriod) external onlyOwner {
        cooldownPeriod = _cooldownPeriod;
    }

    function changeRefillThreshold(uint256 _refillThreshold) external onlyOwner {
        refillThreshold = _refillThreshold;
    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        require(_newOwner != owner, "New owner must be different");
        require(_newOwner != address(this), "Contract cannot be owner");
        require(!blacklistAddresses[_newOwner], "New owner cannot be blacklisted");
        owner = _newOwner;
    }

    function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;

        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdraw failed");
    }

    function withdrawSome(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");

        (bool success, ) = owner.call{value: _amount}("");
        require(success, "Withdraw failed");
    }

    function viewBalance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function addToBlacklist(address _address) external onlyOwner {
        require(_address != address(0), "Invalid address");
        require(_address != owner, "Owner cannot be blacklisted");
        require(_address != address(this), "Contract cannot be blacklisted");
        blacklistAddresses[_address] = true;
    }

    function removeFromBlacklist(address _address) external onlyOwner {
        require(_address != address(0), "Invalid address");
        require(_address != owner, "Owner cannot be removed from blacklist");
        require(_address != address(this), "Contract cannot be removed from blacklist");
        blacklistAddresses[_address] = false;
    }

    function isBlacklisted(address _address) external view returns (bool) {
        return blacklistAddresses[_address];
    }

    function getRequestCount(address _address) external view returns (uint256) {
        return requestCount[_address];
    }

    function getLastRequestTime(address _address) external view returns (uint256) {
        return lastRequestTime[_address];
    }
}