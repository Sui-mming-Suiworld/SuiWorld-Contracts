// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SuiWorldToken.sol";

contract DeployScript is Script {
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcast
        vm.startBroadcast(deployerPrivateKey);

        // Deploy SuiWorldToken
        SuiWorldToken token = new SuiWorldToken();

        // Log deployment info
        console.log("SuiWorldToken deployed at:", address(token));
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Decimals:", token.decimals());
        console.log("Total Supply:", token.totalSupply());
        console.log("Deployer Balance:", token.balanceOf(msg.sender));

        vm.stopBroadcast();

        // Log deployment summary
        console.log("========================");
        console.log("Deployment Summary:");
        console.log("Token Address:", address(token));
        console.log("Deployer:", msg.sender);
        console.log("Network:", getNetworkName());
        console.log("Block:", block.number);
        console.log("========================");
    }

    function getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        if (chainId == 1) return "Ethereum Mainnet";
        else if (chainId == 11155111) return "Sepolia Testnet";
        else if (chainId == 5) return "Goerli Testnet";
        else if (chainId == 137) return "Polygon Mainnet";
        else if (chainId == 80001) return "Mumbai Testnet";
        else if (chainId == 10) return "Optimism Mainnet";
        else if (chainId == 420) return "Optimism Goerli";
        else if (chainId == 42161) return "Arbitrum One";
        else if (chainId == 421613) return "Arbitrum Goerli";
        else if (chainId == 31337) return "Local Hardhat/Anvil";
        else return vm.toString(chainId);
    }
}