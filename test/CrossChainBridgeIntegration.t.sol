// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/BridgeToken.sol";
import "../src/CrossChainBridge.sol";

/**
 * @title CrossChainBridgeIntegrationTest
 * @dev Интеграционные тесты для лабораторной работы
 * 
 * Покрывает требования лабораторной работы:
 * 1. Деплой четырех контрактов (2 моста + 2 токена)
 * 2. Вызов функции депозита в первом контракте
 * 3. Проверка события
 * 4. Чеканка токенов во втором контракте
 */
contract CrossChainBridgeIntegrationTest is Test {
    // Контракты для двух сетей
    BridgeToken public tokenA;
    BridgeToken public tokenB;
    CrossChainBridge public bridgeA;
    CrossChainBridge public bridgeB;
    
    // Тестовые аккаунты
    address public owner;
    address public validator;
    address public user1;
    
    // Константы
    uint256 public constant INITIAL_SUPPLY = 100000 * 10**18;
    uint256 public constant TRANSFER_AMOUNT = 1000 * 10**18;
    uint256 public constant MIN_AMOUNT = 100 * 10**18;
    uint256 public constant MAX_AMOUNT = 10000 * 10**18;
    uint256 public constant FEE_BASIS_POINTS = 50;
    
    // ID сетей
    uint256 public constant CHAIN_A_ID = 11155111; // Sepolia
    uint256 public constant CHAIN_B_ID = 97; // BSC Testnet
    
    function setUp() public {
        // Создаем тестовые аккаунты
        owner = address(this);
        validator = makeAddr("validator");
        user1 = makeAddr("user1");
        
        // Деплоим токены для обеих сетей
        tokenA = new BridgeToken("Bridge Token A", "BRTA", INITIAL_SUPPLY);
        tokenB = new BridgeToken("Bridge Token B", "BRTB", INITIAL_SUPPLY);
        
        // Деплоим мосты для обеих сетей
        bridgeA = new CrossChainBridge(
            address(tokenA),
            validator,
            MIN_AMOUNT,
            MAX_AMOUNT,
            FEE_BASIS_POINTS
        );
        
        bridgeB = new CrossChainBridge(
            address(tokenB),
            validator,
            MIN_AMOUNT,
            MAX_AMOUNT,
            FEE_BASIS_POINTS
        );
        
        // Настраиваем роли токенов для мостов
        tokenA.grantMinterRole(address(bridgeA));
        tokenA.grantBurnerRole(address(bridgeA));
        
        tokenB.grantMinterRole(address(bridgeB));
        tokenB.grantBurnerRole(address(bridgeB));
        
        // Даем токены пользователю
        bool success = tokenA.transfer(user1, TRANSFER_AMOUNT * 2);
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Тест деплоя четырех контрактов (2 моста + 2 токена)
     * Требование лабораторной работы: "Деплой четырех контрактов"
     */
    function testDeployFourContracts() public view {
        // Проверяем, что все контракты деплоены
        assertTrue(address(tokenA) != address(0));
        assertTrue(address(tokenB) != address(0));
        assertTrue(address(bridgeA) != address(0));
        assertTrue(address(bridgeB) != address(0));
        
        // Проверяем, что мосты связаны с правильными токенами
        assertEq(address(bridgeA.TOKEN()), address(tokenA));
        assertEq(address(bridgeB.TOKEN()), address(tokenB));
        
        // Проверяем, что токены имеют правильные роли для мостов
        assertTrue(tokenA.hasRole(tokenA.MINTER_ROLE(), address(bridgeA)));
        assertTrue(tokenA.hasRole(tokenA.BURNER_ROLE(), address(bridgeA)));
        assertTrue(tokenB.hasRole(tokenB.MINTER_ROLE(), address(bridgeB)));
        assertTrue(tokenB.hasRole(tokenB.BURNER_ROLE(), address(bridgeB)));
        
        console.log("=== Deployment Information ===");
        console.log("Token A address:", address(tokenA));
        console.log("Token B address:", address(tokenB));
        console.log("Bridge A address:", address(bridgeA));
        console.log("Bridge B address:", address(bridgeB));
    }
    
    /**
     * @dev Тест вызова функции депозита в первом контракте
     * Требование лабораторной работы: "Вызов функции депозита в первом контракте"
     */
    function testCallDepositFunction() public {
        // Начальные балансы
        uint256 user1BalanceABefore = tokenA.balanceOf(user1);
        uint256 totalSupplyABefore = tokenA.totalSupply();
        
        console.log("=== Before Deposit ===");
        console.log("User1 balance in network A:", user1BalanceABefore / 1e18);
        console.log("Total supply A:", totalSupplyABefore / 1e18);
        
        // Вызов функции депозита в первом контракте
        vm.startPrank(user1);
        bridgeA.lockTokens(TRANSFER_AMOUNT, CHAIN_B_ID);
        vm.stopPrank();
        
        // Проверяем состояние после депозита
        uint256 user1BalanceAAfter = tokenA.balanceOf(user1);
        uint256 totalSupplyAAfter = tokenA.totalSupply();
        
        assertEq(user1BalanceAAfter, user1BalanceABefore - TRANSFER_AMOUNT);
        assertEq(totalSupplyAAfter, totalSupplyABefore - TRANSFER_AMOUNT);
        
        console.log("=== After Deposit ===");
        console.log("User1 balance in network A:", user1BalanceAAfter / 1e18);
        console.log("Total supply A:", totalSupplyAAfter / 1e18);
    }
    
    /**
     * @dev Тест проверки события
     * Требование лабораторной работы: "Проверка события"
     */
    function testEventVerification() public {
        // Проверяем, что событие TokensLocked эмитируется
        vm.startPrank(user1);
        
        // Простая проверка события без детального сравнения параметров
        vm.recordLogs();
        bridgeA.lockTokens(TRANSFER_AMOUNT, CHAIN_B_ID);
        vm.stopPrank();
        
        // Проверяем, что событие было эмитировано
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool eventFound = false;
        
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("TokensLocked(address,uint256,uint256,uint256,uint256,bytes32)")) {
                eventFound = true;
                break;
            }
        }
        
        assertTrue(eventFound, "TokensLocked event should be emitted");
        
        console.log("=== Event Verification ===");
        console.log("TokensLocked event emitted successfully");
    }
    
    /**
     * @dev Тест чеканки токенов во втором контракте
     * Требование лабораторной работы: "Чеканка токенов во втором контракте"
     */
    function testMintTokensInSecondContract() public {
        // Начальные балансы
        uint256 user1BalanceBBefore = tokenB.balanceOf(user1);
        uint256 totalSupplyBBefore = tokenB.totalSupply();
        
        console.log("=== Before Minting ===");
        console.log("User1 balance in network B:", user1BalanceBBefore / 1e18);
        console.log("Total supply B:", totalSupplyBBefore / 1e18);
        
        // Чеканка токенов во втором контракте (прямой вызов mint функции)
        // Это демонстрирует, что мост может чеканить токены
        vm.startPrank(address(bridgeB));
        tokenB.mint(user1, TRANSFER_AMOUNT);
        vm.stopPrank();
        
        // Проверяем состояние после чеканки
        uint256 user1BalanceBAfter = tokenB.balanceOf(user1);
        uint256 totalSupplyBAfter = tokenB.totalSupply();
        
        assertEq(user1BalanceBAfter, user1BalanceBBefore + TRANSFER_AMOUNT);
        assertEq(totalSupplyBAfter, totalSupplyBBefore + TRANSFER_AMOUNT);
        
        console.log("=== After Minting ===");
        console.log("User1 balance in network B:", user1BalanceBAfter / 1e18);
        console.log("Total supply B:", totalSupplyBAfter / 1e18);
    }
}