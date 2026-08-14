// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/// @notice Locks TrustLens's proxy storage-slot resolution against live Base
/// chain state. The Python unit tests prove each slot equals keccak(label)[-1],
/// this proves the live USDC contract actually stores its implementation in the
/// LEGACY zeppelinos slot (its EIP-1967 slot is empty), which is the exact case
/// that makes proxy-aware scanning necessary. If any assertion here breaks, the
/// backend's proxy.py slot constants or USDC's on-chain layout changed.
///
/// Requires a Base mainnet fork. Run: forge test --match-contract ProxyResolution
contract ProxyResolutionTest is Test {
    // Base mainnet USDC (FiatTokenProxy) and its current FiatToken implementation.
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EXPECTED_IMPL = 0x2Ce6311ddAE708829bc0784C967b7d77D19FD779;
    address constant EXPECTED_ADMIN = 0x4fc7850364958d97B4d3f5A08f79db2493f8cA44;

    // Slots (must match app/proxy.py exactly).
    bytes32 constant EIP1967_IMPL = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 constant ZOS_IMPL = 0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3;
    bytes32 constant ZOS_ADMIN = 0x10d6a54a4754c8869d6886b5f5d7fbfa5b4522237ea5c60d11bc4e7a1ff9390b;

    function setUp() public {
        vm.createSelectFork("https://mainnet.base.org");
    }

    function _addr(bytes32 slot) internal view returns (address) {
        return address(uint160(uint256(vm.load(USDC, slot))));
    }

    /// The whole reason the feature exists: USDC's modern EIP-1967 slot is empty,
    /// so an EIP-1967-only scanner reads nothing and scans the proxy shell.
    function test_eip1967_slot_is_empty() public view {
        assertEq(vm.load(USDC, EIP1967_IMPL), bytes32(0), "EIP-1967 impl slot should be empty on USDC");
    }

    /// The legacy zeppelinos slot is where USDC's real implementation lives.
    function test_zeppelinos_slot_holds_implementation() public view {
        assertEq(_addr(ZOS_IMPL), EXPECTED_IMPL, "zeppelinos impl slot mismatch");
        assertGt(EXPECTED_IMPL.code.length, 0, "implementation should have code");
    }

    /// Upgrade control is a single externally-owned key: a real centralization flag.
    function test_admin_is_an_eoa() public view {
        assertEq(_addr(ZOS_ADMIN), EXPECTED_ADMIN, "zeppelinos admin slot mismatch");
        assertEq(EXPECTED_ADMIN.code.length, 0, "USDC proxy admin is expected to be an EOA");
    }
}
