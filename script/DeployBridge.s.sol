// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/BridgeToken.sol";
import "../src/CrossChainBridge.sol";

/**
 * @title DeployBridgeScript
 * @dev Скрипт для деплоя полного кроссчейн моста
 *
 * Этот скрипт:
 * 1. Деплоит токен BridgeToken
 * 2. Деплоит контракт CrossChainBridge
 * 3. Настраивает роли токена для моста
 * 4. Выводит информацию о деплое
 * 5. Сохраняет адреса контрактов
 */
contract DeployBridgeScript is Script {
    function run() external {
        console.log("Starting Cross-Chain Bridge deployment...");

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
        uint256 initialSupply = 100000 * 10 ** 18; // 100,000 токенов

        // Параметры для моста
        address validator = vm.envAddress("VALIDATOR_ADDRESS");
        uint256 bridgeMinAmount = 100 * 10 ** 18; // 100 токенов
        uint256 bridgeMaxAmount = 10000 * 10 ** 18; // 10,000 токенов
        uint256 feeBasisPoints = 50; // 0.5%

        console.log("\nToken parameters:");
        console.log("Name:", tokenName);
        console.log("Symbol:", tokenSymbol);
        console.log("Initial Supply:", initialSupply / 1e18, "BRT");
        console.log("Max Supply:", 1000000, "BRT");

        console.log("\nBridge parameters:");
        console.log("Validator Address:", validator);
        console.log("Min Amount:", bridgeMinAmount / 1e18, "BRT");
        console.log("Max Amount:", bridgeMaxAmount / 1e18, "BRT");
        console.log("Fee:", feeBasisPoints, "basis points");

        // Деплоим контракты
        vm.startBroadcast(deployerPrivateKey);

        console.log("\nDeploying token...");
        BridgeToken bridgeToken = new BridgeToken(tokenName, tokenSymbol, initialSupply);

        console.log("Deploying bridge...");
        CrossChainBridge bridge =
            new CrossChainBridge(address(bridgeToken), validator, bridgeMinAmount, bridgeMaxAmount, feeBasisPoints);

        console.log("Setting up token roles for bridge...");
        bridgeToken.grantMinterRole(address(bridge));
        bridgeToken.grantBurnerRole(address(bridge));

        vm.stopBroadcast();

        console.log("\nDeployment completed successfully!");
        console.log("Token Address:", address(bridgeToken));
        console.log("Bridge Address:", address(bridge));

        // Проверяем деплой
        console.log("\nVerifying deployment:");
        console.log("Token Name:", bridgeToken.name());
        console.log("Token Symbol:", bridgeToken.symbol());
        console.log("Token Decimals:", bridgeToken.decimals());
        console.log("Total Supply:", bridgeToken.totalSupply() / 1e18, "BRT");
        console.log("Max Supply:", bridgeToken.getMaxSupply() / 1e18, "BRT");
        console.log("Available Supply:", bridgeToken.getAvailableSupply() / 1e18, "BRT");
        console.log("Token Owner:", bridgeToken.owner());
        console.log("Deployer Balance:", bridgeToken.balanceOf(deployer) / 1e18, "BRT");
        console.log("Token Paused:", bridgeToken.paused());

        console.log("\nBridge Info:");
        (
            address tokenAddress,
            address validatorAddress,
            uint256 bridgeMinAmountValue,
            uint256 bridgeMaxAmountValue,
            uint256 fee,
            uint256 currentChainId
        ) = bridge.getBridgeInfo();

        console.log("Bridge Token Address:", tokenAddress);
        console.log("Bridge Validator:", validatorAddress);
        console.log("Bridge Min Amount:", bridgeMinAmountValue / 1e18, "BRT");
        console.log("Bridge Max Amount:", bridgeMaxAmountValue / 1e18, "BRT");
        console.log("Bridge Fee:", fee, "basis points");
        console.log("Bridge Chain ID:", currentChainId);
        console.log("Bridge Owner:", bridge.owner());
        console.log("Bridge Paused:", bridge.paused());

        // Проверяем роли
        console.log("\nRole verification:");
        console.log("Bridge has MINTER_ROLE:", bridgeToken.hasRole(bridgeToken.MINTER_ROLE(), address(bridge)));
        console.log("Bridge has BURNER_ROLE:", bridgeToken.hasRole(bridgeToken.BURNER_ROLE(), address(bridge)));

        // Сохраняем информацию о деплое
        string memory deploymentInfo = string(
            abi.encodePacked(
                "=== Cross-Chain Bridge Deployment Info ===\n",
                "Network Chain ID: ",
                vm.toString(block.chainid),
                "\n",
                "Token Address: ",
                vm.toString(address(bridgeToken)),
                "\n",
                "Bridge Address: ",
                vm.toString(address(bridge)),
                "\n",
                "Deployer Address: ",
                vm.toString(deployer),
                "\n",
                "Validator Address: ",
                vm.toString(validator),
                "\n",
                "Token Name: ",
                tokenName,
                "\n",
                "Token Symbol: ",
                tokenSymbol,
                "\n",
                "Initial Supply: ",
                vm.toString(initialSupply / 1e18),
                " BRT\n",
                "Max Supply: 1000000 BRT\n",
                "Min Amount: ",
                vm.toString(bridgeMinAmount / 1e18),
                " BRT\n",
                "Max Amount: ",
                vm.toString(bridgeMaxAmount / 1e18),
                " BRT\n",
                "Fee: ",
                vm.toString(feeBasisPoints),
                " basis points\n",
                "Deployment Timestamp: ",
                vm.toString(block.timestamp),
                "\n",
                "Block Number: ",
                vm.toString(block.number),
                "\n"
            )
        );

        // Создаем папку deployments если её нет
        string[] memory mkdirCommand = new string[](3);
        mkdirCommand[0] = "mkdir";
        mkdirCommand[1] = "-p";
        mkdirCommand[2] = "deployments";
        vm.ffi(mkdirCommand);

        // Сохраняем информацию о деплое
        string memory networkName = vm.envOr("NETWORK_NAME", string("unknown"));
        string memory deploymentFile = string(abi.encodePacked("deployments/bridge_", networkName, ".txt"));

        vm.writeFile(deploymentFile, deploymentInfo);

        console.log("\nDeployment info saved to:", deploymentFile);

        console.log("\nBridge deployment completed successfully!");
        console.log("\nNext steps:");
        console.log("1. Check token balance: cast call <token_address> 'balanceOf(address)' <your_address>");
        console.log("2. Check bridge info: cast call <bridge_address> 'getBridgeInfo()'");
        console.log(
            "3. To lock tokens: cast send <bridge_address> 'lockTokens(uint256,uint256)' <amount> <target_chain_id> --private-key <your_key>"
        );
        console.log(
            "4. To unlock tokens: cast send <bridge_address> 'unlockTokens(address,uint256,uint256,uint256,bytes)' <user> <amount> <nonce> <source_chain_id> <signature> --private-key <validator_key>"
        );
        console.log("5. Update bridge server configuration with new addresses");
    }
}
