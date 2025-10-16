// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./BridgeToken.sol";

/**
 * @title CrossChainBridge
 * @dev Контракт моста для кроссчейн переводов токенов
 * 
 * Основные особенности:
 * 1. Блокирует токены в исходной сети (burn)
 * 2. Разблокирует токены в целевой сети (mint)
 * 3. Защита от повторной обработки через nonce
 * 4. Подпись валидатора для авторизации
 * 5. События для отслеживания операций
 * 6. Pausable для экстренной остановки
 */
contract CrossChainBridge is Ownable, Pausable, ReentrancyGuard {
    // Ссылка на токен моста
    BridgeToken public immutable TOKEN;
    
    // Адрес валидатора (подписывает разблокировку)
    address public validator;
    
    // Минимальная и максимальная сумма для перевода
    uint256 public minAmount;
    uint256 public maxAmount;
    
    // Комиссия за перевод (в базисных пунктах, 100 = 1%)
    uint256 public feeBasisPoints;
    
    // ID текущей сети
    uint256 public immutable CURRENT_CHAIN_ID;
    
    // Маппинг использованных nonce (защита от повторной обработки)
    mapping(uint256 => bool) public usedNonces;
    
    // События
    event TokensLocked(
        address indexed user,
        uint256 amount,
        uint256 nonce,
        uint256 indexed sourceChainId,
        uint256 indexed targetChainId,
        bytes32 transferHash
    );
    
    event TokensUnlocked(
        address indexed user,
        uint256 amount,
        uint256 nonce,
        uint256 indexed sourceChainId,
        uint256 indexed targetChainId,
        bytes32 transferHash
    );
    
    event ValidatorUpdated(address indexed oldValidator, address indexed newValidator);
    event LimitsUpdated(uint256 oldMinAmount, uint256 newMinAmount, uint256 oldMaxAmount, uint256 newMaxAmount);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    
    // Ошибки
    error InvalidAmount();
    error InvalidNonce();
    error InvalidSignature();
    error InvalidChainId();
    error TransferAlreadyProcessed();
    error InsufficientBalance();
    error OnlyValidator();
    
    /**
     * @dev Конструктор моста
     * @param _token Адрес токена моста
     * @param _validator Адрес валидатора
     * @param _minAmount Минимальная сумма для перевода
     * @param _maxAmount Максимальная сумма для перевода
     * @param _feeBasisPoints Комиссия в базисных пунктах
     */
    constructor(
        address _token,
        address _validator,
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _feeBasisPoints
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token address");
        require(_validator != address(0), "Invalid validator address");
        require(_minAmount > 0, "Invalid min amount");
        require(_maxAmount >= _minAmount, "Invalid max amount");
        require(_feeBasisPoints <= 1000, "Fee too high"); // Максимум 10%
        
        TOKEN = BridgeToken(_token);
        validator = _validator;
        minAmount = _minAmount;
        maxAmount = _maxAmount;
        feeBasisPoints = _feeBasisPoints;
        CURRENT_CHAIN_ID = block.chainid;
    }
    
    /**
     * @dev Блокировка токенов для перевода в другую сеть
     * @param amount Количество токенов для блокировки
     * @param targetChainId ID целевой сети
     */
    function lockTokens(uint256 amount, uint256 targetChainId) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        if (amount < minAmount || amount > maxAmount) {
            revert InvalidAmount();
        }
        
        if (targetChainId == CURRENT_CHAIN_ID) {
            revert InvalidChainId();
        }
        
        // Проверяем баланс пользователя
        if (TOKEN.balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }
        
        // Генерируем уникальный nonce
        uint256 nonce = uint256(keccak256(abi.encodePacked(
            msg.sender,
            amount,
            targetChainId,
            block.timestamp,
            block.number
        )));
        
        // Проверяем, что nonce не использовался
        if (usedNonces[nonce]) {
            revert InvalidNonce();
        }
        
        // Сжигаем токены (блокируем)
        TOKEN.burn(msg.sender, amount);
        
        // Создаем хеш перевода
        bytes32 transferHash = keccak256(abi.encodePacked(
            msg.sender,
            amount,
            nonce,
            CURRENT_CHAIN_ID,
            targetChainId
        ));
        
        // Эмитируем событие
        emit TokensLocked(
            msg.sender,
            amount,
            nonce,
            CURRENT_CHAIN_ID,
            targetChainId,
            transferHash
        );
    }
    
    /**
     * @dev Разблокировка токенов в целевой сети
     * @param user Адрес получателя
     * @param amount Количество токенов
     * @param nonce Уникальный номер перевода
     * @param sourceChainId ID исходной сети
     * @param signature Подпись валидатора
     */
    function unlockTokens(
        address user,
        uint256 amount,
        uint256 nonce,
        uint256 sourceChainId,
        bytes memory signature
    ) external whenNotPaused nonReentrant {
        // Проверяем, что nonce не использовался
        if (usedNonces[nonce]) {
            revert TransferAlreadyProcessed();
        }
        
        // Проверяем подпись валидатора
        if (!_verifySignature(user, amount, nonce, sourceChainId, signature)) {
            revert InvalidSignature();
        }
        
        // Отмечаем nonce как использованный
        usedNonces[nonce] = true;
        
        // Создаем хеш перевода
        bytes32 transferHash = keccak256(abi.encodePacked(
            user,
            amount,
            nonce,
            sourceChainId,
            CURRENT_CHAIN_ID
        ));
        
        // Выпускаем токены получателю
        TOKEN.mint(user, amount);
        
        // Эмитируем событие
        emit TokensUnlocked(
            user,
            amount,
            nonce,
            sourceChainId,
            CURRENT_CHAIN_ID,
            transferHash
        );
    }
    
    /**
     * @dev Проверка подписи валидатора
     * @param user Адрес пользователя
     * @param amount Количество токенов
     * @param nonce Уникальный номер
     * @param sourceChainId ID исходной сети
     * @param signature Подпись
     * @return true если подпись валидна
     */
    function _verifySignature(
        address user,
        uint256 amount,
        uint256 nonce,
        uint256 sourceChainId,
        bytes memory signature
    ) internal view returns (bool) {
        // Создаем сообщение для подписи
        bytes32 messageHash = keccak256(abi.encodePacked(
            user,
            amount,
            nonce,
            sourceChainId,
            CURRENT_CHAIN_ID
        ));
        
        // Восстанавливаем адрес из подписи
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            messageHash
        ));
        
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
        address signer = ecrecover(ethSignedMessageHash, v, r, s);
        
        return signer == validator;
    }
    
    /**
     * @dev Разделение подписи на компоненты
     * @param signature Подпись
     * @return r Компонент r подписи
     * @return s Компонент s подписи
     * @return v Компонент v подписи
     */
    function _splitSignature(bytes memory signature) 
        internal 
        pure 
        returns (bytes32 r, bytes32 s, uint8 v) 
    {
        require(signature.length == 65, "Invalid signature length");
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
    }
    
    /**
     * @dev Обновление адреса валидатора (только владелец)
     * @param newValidator Новый адрес валидатора
     */
    function updateValidator(address newValidator) external onlyOwner {
        require(newValidator != address(0), "Invalid validator address");
        address oldValidator = validator;
        validator = newValidator;
        emit ValidatorUpdated(oldValidator, newValidator);
    }
    
    /**
     * @dev Обновление лимитов переводов (только владелец)
     * @param newMinAmount Новый минимальный лимит
     * @param newMaxAmount Новый максимальный лимит
     */
    function updateLimits(uint256 newMinAmount, uint256 newMaxAmount) external onlyOwner {
        require(newMinAmount > 0, "Invalid min amount");
        require(newMaxAmount >= newMinAmount, "Invalid max amount");
        
        uint256 oldMinAmount = minAmount;
        uint256 oldMaxAmount = maxAmount;
        
        minAmount = newMinAmount;
        maxAmount = newMaxAmount;
        
        emit LimitsUpdated(oldMinAmount, newMinAmount, oldMaxAmount, newMaxAmount);
    }
    
    /**
     * @dev Обновление комиссии (только владелец)
     * @param newFeeBasisPoints Новая комиссия в базисных пунктах
     */
    function updateFee(uint256 newFeeBasisPoints) external onlyOwner {
        require(newFeeBasisPoints <= 1000, "Fee too high"); // Максимум 10%
        
        uint256 oldFee = feeBasisPoints;
        feeBasisPoints = newFeeBasisPoints;
        
        emit FeeUpdated(oldFee, newFeeBasisPoints);
    }
    
    /**
     * @dev Приостановка работы моста (только владелец)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Возобновление работы моста (только владелец)
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Получение информации о мосте
     * @return tokenAddress Адрес токена
     * @return validatorAddress Адрес валидатора
     * @return minAmountValue Минимальная сумма
     * @return maxAmountValue Максимальная сумма
     * @return fee Комиссия в базисных пунктах
     * @return currentChainIdValue ID текущей сети
     */
    function getBridgeInfo() external view returns (
        address tokenAddress,
        address validatorAddress,
        uint256 minAmountValue,
        uint256 maxAmountValue,
        uint256 fee,
        uint256 currentChainIdValue
    ) {
        return (
            address(TOKEN),
            validator,
            minAmount,
            maxAmount,
            feeBasisPoints,
            CURRENT_CHAIN_ID
        );
    }
    
    /**
     * @dev Проверка использования nonce
     * @param nonce Номер для проверки
     * @return true если nonce уже использовался
     */
    function isNonceUsed(uint256 nonce) external view returns (bool) {
        return usedNonces[nonce];
    }
    
    /**
     * @dev Получение хеша сообщения для подписи
     * @param user Адрес пользователя
     * @param amount Количество токенов
     * @param nonce Уникальный номер
     * @param sourceChainId ID исходной сети
     * @return Хеш сообщения
     */
    function getMessageHash(
        address user,
        uint256 amount,
        uint256 nonce,
        uint256 sourceChainId
    ) external view returns (bytes32) {
        return keccak256(abi.encodePacked(
            user,
            amount,
            nonce,
            sourceChainId,
            CURRENT_CHAIN_ID
        ));
    }
}
