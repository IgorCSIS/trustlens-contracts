// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title  PaymentGate
/// @notice On-chain monetization layer for TrustLens contract scans.
///         Two products:
///           1. Pay-per-scan  — pay `scanPrice` to unlock one deep report for a
///              specific target contract. The off-chain backend listens for the
///              `ScanPurchased` event (matched by `paymentId`) before returning
///              the AI report.
///           2. Time pass     — pay `passPrice` for `passDuration` of unlimited
///              scans. The backend checks `hasActivePass(user)`.
/// @dev    Deployed on Base (Base Sepolia for testing). Funds accrue to the
///         contract and are pulled by the owner via `withdraw`.
contract PaymentGate is Ownable, ReentrancyGuard {
    /// @notice Price in wei for a single deep scan.
    uint256 public scanPrice;
    /// @notice Price in wei for a time-limited unlimited pass.
    uint256 public passPrice;
    /// @notice Duration in seconds granted per pass purchase.
    uint256 public passDuration;

    /// @notice Lifetime count of scans purchased (analytics).
    uint256 public totalScansPurchased;

    /// @dev Monotonic id assigned to each scan purchase; links on-chain payment
    ///      to the off-chain report request. Starts at 1.
    uint256 private _paymentCounter;

    /// @notice user => unix timestamp their pass is valid until.
    mapping(address => uint256) public passExpiry;

    event ScanPurchased(
        uint256 indexed paymentId,
        address indexed payer,
        address indexed target,
        uint256 amount,
        uint256 timestamp
    );
    event PassPurchased(address indexed payer, uint256 amount, uint256 expiry);
    event ScanPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event PassConfigUpdated(uint256 newPrice, uint256 newDuration);
    event Withdrawn(address indexed to, uint256 amount);

    error IncorrectPayment(uint256 sent, uint256 required);
    error ZeroAddressTarget();
    error ZeroAddressRecipient();
    error NothingToWithdraw();
    error WithdrawFailed();

    /// @param _scanPrice    wei required per deep scan
    /// @param _passPrice    wei required per pass purchase
    /// @param _passDuration seconds granted per pass purchase
    /// @param initialOwner  address that can set prices and withdraw funds
    constructor(
        uint256 _scanPrice,
        uint256 _passPrice,
        uint256 _passDuration,
        address initialOwner
    ) Ownable(initialOwner) {
        scanPrice = _scanPrice;
        passPrice = _passPrice;
        passDuration = _passDuration;
    }

    // ---------------------------------------------------------------------
    // User actions
    // ---------------------------------------------------------------------

    /// @notice Pay for a single deep scan of `target`.
    /// @dev    Requires exact payment to keep backend accounting unambiguous.
    /// @param  target the contract address the buyer wants scanned
    /// @return paymentId id the backend uses to match this payment to a report
    function purchaseScan(address target)
        external
        payable
        nonReentrant
        returns (uint256 paymentId)
    {
        if (target == address(0)) revert ZeroAddressTarget();
        if (msg.value != scanPrice) revert IncorrectPayment(msg.value, scanPrice);

        paymentId = ++_paymentCounter;
        totalScansPurchased++;

        emit ScanPurchased(paymentId, msg.sender, target, msg.value, block.timestamp);
    }

    /// @notice Buy or extend a time-limited unlimited-scan pass.
    /// @dev    Purchasing while a pass is still active extends from the current
    ///         expiry rather than from `block.timestamp`, so users never lose
    ///         paid time.
    function purchasePass() external payable nonReentrant {
        if (msg.value != passPrice) revert IncorrectPayment(msg.value, passPrice);

        uint256 current = passExpiry[msg.sender];
        uint256 base = current > block.timestamp ? current : block.timestamp;
        uint256 newExpiry = base + passDuration;
        passExpiry[msg.sender] = newExpiry;

        emit PassPurchased(msg.sender, msg.value, newExpiry);
    }

    /// @notice Whether `user` currently holds an active pass.
    function hasActivePass(address user) external view returns (bool) {
        return passExpiry[user] > block.timestamp;
    }

    // ---------------------------------------------------------------------
    // Admin
    // ---------------------------------------------------------------------

    function setScanPrice(uint256 newPrice) external onlyOwner {
        emit ScanPriceUpdated(scanPrice, newPrice);
        scanPrice = newPrice;
    }

    function setPassConfig(uint256 newPrice, uint256 newDuration) external onlyOwner {
        passPrice = newPrice;
        passDuration = newDuration;
        emit PassConfigUpdated(newPrice, newDuration);
    }

    /// @notice Withdraw the full contract balance to `to`.
    function withdraw(address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddressRecipient();

        uint256 balance = address(this).balance;
        if (balance == 0) revert NothingToWithdraw();

        (bool ok, ) = to.call{value: balance}("");
        if (!ok) revert WithdrawFailed();

        emit Withdrawn(to, balance);
    }
}
