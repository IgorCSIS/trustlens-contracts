// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PaymentGate} from "../src/PaymentGate.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract PaymentGateTest is Test {
    PaymentGate internal gate;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal target = makeAddr("token");

    uint256 internal constant SCAN_PRICE = 0.0005 ether;
    uint256 internal constant PASS_PRICE = 0.005 ether;
    uint256 internal constant PASS_DURATION = 30 days;

    // Mirror of the contract events for expectEmit.
    event ScanPurchased(
        uint256 indexed paymentId,
        address indexed payer,
        address indexed target,
        uint256 amount,
        uint256 timestamp
    );
    event PassPurchased(address indexed payer, uint256 amount, uint256 expiry);

    function setUp() public {
        gate = new PaymentGate(SCAN_PRICE, PASS_PRICE, PASS_DURATION, owner);
        vm.deal(alice, 10 ether);
    }

    // ------------------------------------------------------------------
    // purchaseScan
    // ------------------------------------------------------------------

    function test_PurchaseScan_EmitsAndTracks() public {
        vm.expectEmit(true, true, true, true);
        emit ScanPurchased(1, alice, target, SCAN_PRICE, block.timestamp);

        vm.prank(alice);
        uint256 id = gate.purchaseScan{value: SCAN_PRICE}(target);

        assertEq(id, 1, "first paymentId should be 1");
        assertEq(gate.totalScansPurchased(), 1);
        assertEq(address(gate).balance, SCAN_PRICE);
    }

    function test_PurchaseScan_IncrementsPaymentId() public {
        vm.startPrank(alice);
        uint256 first = gate.purchaseScan{value: SCAN_PRICE}(target);
        uint256 second = gate.purchaseScan{value: SCAN_PRICE}(target);
        vm.stopPrank();
        assertEq(first, 1);
        assertEq(second, 2);
    }

    function test_PurchaseScan_RevertsOnWrongPayment() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(PaymentGate.IncorrectPayment.selector, uint256(1), SCAN_PRICE)
        );
        gate.purchaseScan{value: 1 wei}(target);
    }

    function test_PurchaseScan_RevertsOnZeroTarget() public {
        vm.prank(alice);
        vm.expectRevert(PaymentGate.ZeroAddressTarget.selector);
        gate.purchaseScan{value: SCAN_PRICE}(address(0));
    }

    // ------------------------------------------------------------------
    // purchasePass
    // ------------------------------------------------------------------

    function test_PurchasePass_SetsExpiryAndFlag() public {
        vm.prank(alice);
        gate.purchasePass{value: PASS_PRICE}();

        assertTrue(gate.hasActivePass(alice));
        assertEq(gate.passExpiry(alice), block.timestamp + PASS_DURATION);
    }

    function test_PurchasePass_ExtendsFromCurrentExpiry() public {
        vm.startPrank(alice);
        gate.purchasePass{value: PASS_PRICE}();
        uint256 firstExpiry = gate.passExpiry(alice);
        gate.purchasePass{value: PASS_PRICE}();
        vm.stopPrank();

        // stacked, not reset
        assertEq(gate.passExpiry(alice), firstExpiry + PASS_DURATION);
    }

    function test_HasActivePass_FalseAfterExpiry() public {
        vm.prank(alice);
        gate.purchasePass{value: PASS_PRICE}();
        assertTrue(gate.hasActivePass(alice));

        vm.warp(block.timestamp + PASS_DURATION + 1);
        assertFalse(gate.hasActivePass(alice));
    }

    // ------------------------------------------------------------------
    // admin: pricing
    // ------------------------------------------------------------------

    function test_SetScanPrice_OwnerCanUpdate() public {
        vm.prank(owner);
        gate.setScanPrice(0.001 ether);
        assertEq(gate.scanPrice(), 0.001 ether);
    }

    function test_SetScanPrice_RevertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        );
        gate.setScanPrice(0.001 ether);
    }

    function test_SetPassConfig_OwnerCanUpdate() public {
        vm.prank(owner);
        gate.setPassConfig(0.01 ether, 7 days);
        assertEq(gate.passPrice(), 0.01 ether);
        assertEq(gate.passDuration(), 7 days);
    }

    // ------------------------------------------------------------------
    // admin: withdraw
    // ------------------------------------------------------------------

    function test_Withdraw_TransfersFullBalanceToOwner() public {
        vm.prank(alice);
        gate.purchaseScan{value: SCAN_PRICE}(target);

        uint256 balBefore = owner.balance;
        vm.prank(owner);
        gate.withdraw(payable(owner));

        assertEq(owner.balance, balBefore + SCAN_PRICE);
        assertEq(address(gate).balance, 0);
    }

    function test_Withdraw_RevertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        );
        gate.withdraw(payable(alice));
    }

    function test_Withdraw_RevertsWhenEmpty() public {
        vm.prank(owner);
        vm.expectRevert(PaymentGate.NothingToWithdraw.selector);
        gate.withdraw(payable(owner));
    }

    function test_Withdraw_RevertsOnZeroRecipient() public {
        vm.prank(alice);
        gate.purchaseScan{value: SCAN_PRICE}(target);

        vm.prank(owner);
        vm.expectRevert(PaymentGate.ZeroAddressRecipient.selector);
        gate.withdraw(payable(address(0)));
    }

    // ------------------------------------------------------------------
    // fuzz
    // ------------------------------------------------------------------

    /// Any payment != scanPrice must revert.
    function testFuzz_PurchaseScan_WrongValueReverts(uint96 sent) public {
        vm.assume(sent != SCAN_PRICE);
        vm.deal(alice, uint256(sent) + 1 ether);
        vm.prank(alice);
        vm.expectRevert(); // IncorrectPayment
        gate.purchaseScan{value: sent}(target);
    }

    /// Exact payment always succeeds and accrues to the contract.
    function testFuzz_PurchaseScan_ExactValueSucceeds(uint8 count) public {
        vm.assume(count > 0);
        vm.deal(alice, uint256(count) * SCAN_PRICE + 1 ether);
        vm.startPrank(alice);
        for (uint256 i = 0; i < count; i++) {
            gate.purchaseScan{value: SCAN_PRICE}(target);
        }
        vm.stopPrank();
        assertEq(gate.totalScansPurchased(), count);
        assertEq(address(gate).balance, uint256(count) * SCAN_PRICE);
    }
}
