// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PaymentGate} from "../src/PaymentGate.sol";

/// @notice Deploys PaymentGate. Prices/duration are read from env with sane
///         testnet defaults so you can `forge script` without extra config.
///
/// Usage (Base Sepolia):
///   forge script script/Deploy.s.sol:DeployPaymentGate \
///     --rpc-url base_sepolia --broadcast --verify -vvvv
///
/// The deployer key is supplied by Foundry at run time (--private-key,
/// --account, or --ledger). It is NEVER written in code or committed.
contract DeployPaymentGate is Script {
    function run() external returns (PaymentGate gate) {
        uint256 scanPrice = vm.envOr("SCAN_PRICE_WEI", uint256(0.0005 ether));
        uint256 passPrice = vm.envOr("PASS_PRICE_WEI", uint256(0.005 ether));
        uint256 passDuration = vm.envOr("PASS_DURATION_SECONDS", uint256(30 days));

        vm.startBroadcast();
        address owner = msg.sender; // deployer becomes owner
        gate = new PaymentGate(scanPrice, passPrice, passDuration, owner);
        vm.stopBroadcast();

        console2.log("PaymentGate deployed at:", address(gate));
        console2.log("owner:               ", owner);
        console2.log("scanPrice (wei):     ", scanPrice);
        console2.log("passPrice (wei):     ", passPrice);
        console2.log("passDuration (sec):  ", passDuration);
    }
}
