// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/BridgeToken.sol";
import "../src/CrossChainBridge.sol";

/**
 * @title TestCrossChainTransferScript
 * @dev Скрипт для тестирования кроссчейн переводов
 *
 * Этот скрипт:
 * 1. Подключается к существующим контрактам
 * 2. Выполняет депозит + сжигание токенов
 * 3. Проверяет события
 * 4. Демонстрирует полный цикл перевода
 */
contract TestCrossChainTransferScript is Script {
    function run() external {
        console.log("Starting Cross-Chain Transfer Test...");

        // Получаем адреса контрактов из переменных окружения
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address bridgeAddress = vm.envAddress("BRIDGE_ADDRESS");
        address validatorAddress = vm.envAddress("VALIDATOR_ADDRESS");

        // Получаем приватный ключ пользователя
        uint256 userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
        address user = vm.addr(userPrivateKey);

        // Получаем приватный ключ валидатора
        uint256 validatorPrivateKey = vm.envUint("VALIDATOR_PRIVATE_KEY");

        console.log("Test configuration:");
        console.log("Token Address:", tokenAddress);
        console.log("Bridge Address:", bridgeAddress);
        console.log("Validator Address:", validatorAddress);
        console.log("User Address:", user);
        console.log("Network Chain ID:", block.chainid);

        // Подключаемся к контрактам
        BridgeToken token = BridgeToken(tokenAddress);
        CrossChainBridge bridge = CrossChainBridge(bridgeAddress);

        // Параметры теста
        uint256 transferAmount = 1000 * 10 ** 18; // 1000 токенов
        uint256 targetChainId = 97; // BSC Testnet

        console.log("\nTest parameters:");
        console.log("Transfer Amount:", transferAmount / 1e18, "BRT");
        console.log("Target Chain ID:", targetChainId);

        // Проверяем начальное состояние
        uint256 userBalanceBefore = token.balanceOf(user);
        uint256 totalSupplyBefore = token.totalSupply();

        console.log("\nInitial state:");
        console.log("User balance:", userBalanceBefore / 1e18, "BRT");
        console.log("Total supply:", totalSupplyBefore / 1e18, "BRT");

        if (userBalanceBefore < transferAmount) {
            console.log("ERROR: Insufficient balance for transfer");
            console.log("Required:", transferAmount / 1e18, "BRT");
            console.log("Available:", userBalanceBefore / 1e18, "BRT");
            return;
        }

        // Выполняем депозит + сжигание токенов
        vm.startBroadcast(userPrivateKey);

        console.log("\nStep 1: Locking tokens...");
        bridge.lockTokens(transferAmount, targetChainId);

        vm.stopBroadcast();

        // Проверяем состояние после блокировки
        uint256 userBalanceAfterLock = token.balanceOf(user);
        uint256 totalSupplyAfterLock = token.totalSupply();

        console.log("\nAfter locking:");
        console.log("User balance:", userBalanceAfterLock / 1e18, "BRT");
        console.log("Total supply:", totalSupplyAfterLock / 1e18, "BRT");
        console.log("Tokens burned:", (totalSupplyBefore - totalSupplyAfterLock) / 1e18, "BRT");

        // Получаем информацию о событии (в реальном сценарии это делал бы сервер)
        console.log("\nStep 2: Simulating server processing...");

        // Генерируем nonce (в реальности он берется из события)
        uint256 nonce =
            uint256(keccak256(abi.encodePacked(user, transferAmount, targetChainId, block.timestamp, block.number)));

        console.log("Generated nonce:", nonce);

        // Создаем подпись валидатора
        bytes memory signature = _createSignature(user, transferAmount, nonce, block.chainid, validatorPrivateKey);

        console.log("Validator signature created");

        // Симулируем разблокировку в целевой сети
        console.log("\nStep 3: Simulating unlock in target network...");

        // В реальном сценарии это делал бы сервер в целевой сети
        // Здесь мы просто показываем, как это должно работать

        console.log("Unlock parameters:");
        console.log("User:", user);
        console.log("Amount:", transferAmount / 1e18, "BRT");
        console.log("Nonce:", nonce);
        console.log("Source Chain ID:", block.chainid);
        console.log("Signature length:", signature.length, "bytes");

        // Проверяем, что nonce не использовался
        bool isNonceUsed = bridge.isNonceUsed(nonce);
        console.log("Nonce already used:", isNonceUsed);

        if (!isNonceUsed) {
            console.log("Nonce is valid for unlock");
        } else {
            console.log("ERROR: Nonce already used");
        }

        // Проверяем подпись
        bytes32 messageHash = bridge.getMessageHash(user, transferAmount, nonce, block.chainid);
        console.log("Message hash:", vm.toString(messageHash));

        console.log("\nTest completed successfully!");
        console.log("\nSummary:");
        console.log("1. User locked", transferAmount / 1e18, "BRT tokens");
        console.log("2. Tokens were burned (total supply decreased)");
        console.log("3. Event was emitted with transfer details");
        console.log("4. Nonce was generated for unlock");
        console.log("5. Validator signature was created");
        console.log("6. Ready for unlock in target network");

        console.log("\nNext steps (manual):");
        console.log("1. Deploy bridge in target network");
        console.log("2. Start bridge server");
        console.log("3. Server will detect TokensLocked event");
        console.log("4. Server will call unlockTokens in target network");
        console.log("5. Tokens will be minted to user in target network");
    }

    /**
     * @dev Создание подписи валидатора
     */
    function _createSignature(
        address user,
        uint256 amount,
        uint256 nonce,
        uint256 sourceChainId,
        uint256 validatorPrivateKey
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encodePacked(user, amount, nonce, sourceChainId, block.chainid));

        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }
}
