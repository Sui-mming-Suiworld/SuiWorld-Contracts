// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SuiWorldToken.sol";

contract SetupNTTScript is Script {
    function run() external {
        // Configuration
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address nttManagerAddress = vm.envAddress("NTT_MANAGER_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcast
        vm.startBroadcast(deployerPrivateKey);

        // Get token instance
        SuiWorldToken token = SuiWorldToken(tokenAddress);

        // Set NTT Manager
        console.log("Setting NTT Manager...");
        console.log("Token:", tokenAddress);
        console.log("NTT Manager:", nttManagerAddress);

        token.setNTTManager(nttManagerAddress);

        console.log("NTT Manager set successfully!");

        // For burn-and-mint mode: Transfer ownership to NTT Manager if needed
        // Note: Only do this if you want NTT Manager to control minting
        // token.transferOwnership(nttManagerAddress);

        vm.stopBroadcast();

        // Verify setup
        console.log("Verification:");
        console.log("Current NTT Manager:", token.nttManager());
        console.log("Current Owner:", token.owner());
    }
}