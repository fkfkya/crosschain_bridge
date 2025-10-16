// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/BridgeToken.sol";

/**
 * @title DeployTokenScript
 * @dev Скрипт для деплоя токена BridgeToken
 * 
 * Этот скрипт:
 * 1. Деплоит контракт BridgeToken
 * 2. Выводит информацию о деплое
 * 3. Сохраняет адреса контрактов для дальнейшего использования
 */
contract DeployTokenScript is Script {
    function run() external {
        console.log("Starting BridgeToken deployment...");
        
        // Получаем приватный ключ из переменных окружения
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployment info:");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance / 1e18, "ETH");
        console.log("Network Chain ID:", block.chainid);
        
        // Параметры для токена
        string memory tokenName = "Bridge Token";
        string memory tokenSymbol = "BRT";
        uint256 initialSupply = 100000 * 10**18; // 100,000 токенов
        
        console.log("\nToken parameters:");
        console.log("Name:", tokenName);
        console.log("Symbol:", tokenSymbol);
        console.log("Initial Supply:", initialSupply / 1e18, "BRT");
        console.log("Max Supply:", 1000000, "BRT");
        
        // Деплоим токен
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\nDeploying token...");
        BridgeToken bridgeToken = new BridgeToken(
            tokenName,
            tokenSymbol,
            initialSupply
        );
        
        vm.stopBroadcast();
        
        console.log("Token deployed successfully!");
        console.log("Token Address:", address(bridgeToken));
        
        // Проверяем деплой
        console.log("\nVerifying deployment:");
        console.log("Token Name:", bridgeToken.name());
        console.log("Token Symbol:", bridgeToken.symbol());
        console.log("Token Decimals:", bridgeToken.decimals());
        console.log("Total Supply:", bridgeToken.totalSupply() / 1e18, "BRT");
        console.log("Max Supply:", bridgeToken.getMaxSupply() / 1e18, "BRT");
        console.log("Available Supply:", bridgeToken.getAvailableSupply() / 1e18, "BRT");
        console.log("Owner:", bridgeToken.owner());
        console.log("Deployer Balance:", bridgeToken.balanceOf(deployer) / 1e18, "BRT");
        console.log("Paused:", bridgeToken.paused());
        
        // Сохраняем информацию о деплое
        string memory deploymentInfo = string(abi.encodePacked(
            "=== BridgeToken Deployment Info ===\n",
            "Network Chain ID: ", vm.toString(block.chainid), "\n",
            "Token Address: ", vm.toString(address(bridgeToken)), "\n",
            "Deployer Address: ", vm.toString(deployer), "\n",
            "Token Name: ", tokenName, "\n",
            "Token Symbol: ", tokenSymbol, "\n",
            "Initial Supply: ", vm.toString(initialSupply / 1e18), " BRT\n",
            "Max Supply: 1000000 BRT\n",
            "Deployment Timestamp: ", vm.toString(block.timestamp), "\n",
            "Block Number: ", vm.toString(block.number), "\n"
        ));
        
        // Создаем папку deployments если её нет
        string[] memory mkdirCommand = new string[](3);
        mkdirCommand[0] = "mkdir";
        mkdirCommand[1] = "-p";
        mkdirCommand[2] = "deployments";
        vm.ffi(mkdirCommand);
        
        // Сохраняем информацию о деплое
        string memory networkName = vm.envOr("NETWORK_NAME", string("unknown"));
        string memory deploymentFile = string(abi.encodePacked("deployments/token_", networkName, ".txt"));
        
        vm.writeFile(deploymentFile, deploymentInfo);
        
        console.log("\nDeployment info saved to:", deploymentFile);
        
        console.log("\nToken deployment completed successfully!");
        console.log("\nNext steps:");
        console.log("1. Check token balance: cast call <token_address> 'balanceOf(address)' <your_address>");
        console.log("2. To mint tokens: cast send <token_address> 'mint(address,uint256)' <recipient> <amount> --private-key <your_key>");
        console.log("3. To burn tokens: cast send <token_address> 'burn(address,uint256)' <from> <amount> --private-key <your_key>");
    }
}
