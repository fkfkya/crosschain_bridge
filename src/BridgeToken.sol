// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title BridgeToken
 * @dev ERC20 токен для кроссчейн моста с возможностью mint/burn
 *
 * Основные особенности:
 * 1. Наследует стандартный ERC20 от OpenZeppelin
 * 2. Добавляет функции mint (выпуск) и burn (сжигание) токенов
 * 3. Использует Ownable для контроля доступа - только владелец может mint/burn
 * 4. Поддерживает Pausable для экстренной остановки операций
 * 5. Имеет максимальное предложение токенов для защиты от инфляции
 */
contract BridgeToken is ERC20, Ownable, Pausable, AccessControl {
    // Максимальное предложение токенов (защита от неограниченного выпуска)
    uint256 public constant MAX_SUPPLY = 1000000 * 10 ** 18; // 1 миллион токенов

    // Роли для контроля доступа
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // События для отслеживания операций mint/burn
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    /**
     * @dev Конструктор токена
     * @param name Название токена (например, "Bridge Token")
     * @param symbol Символ токена (например, "BRT")
     * @param initialSupply Начальное предложение токенов
     */
    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        // Проверяем, что начальное предложение не превышает максимум
        require(initialSupply <= MAX_SUPPLY, "Initial supply exceeds maximum");

        // Настраиваем роли
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);

        // Выпускаем начальное предложение владельцу контракта
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Выпуск новых токенов (только для владельца)
     * @param to Адрес получателя новых токенов
     * @param amount Количество токенов для выпуска
     *
     * Важно: Эта функция может вызывать только владелец контракта (owner)
     * Это обеспечивает контроль над предложением токенов
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        // Проверяем, что выпуск не превысит максимальное предложение
        require(totalSupply() + amount <= MAX_SUPPLY, "Minting would exceed maximum supply");

        // Выпускаем токены
        _mint(to, amount);

        // Эмитируем событие для отслеживания
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Сжигание токенов (только для владельца)
     * @param from Адрес, с которого сжигаются токены
     * @param amount Количество токенов для сжигания
     *
     * Важно: Эта функция может вызывать только владелец контракта
     * Позволяет уменьшить общее предложение токенов
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) whenNotPaused {
        // Сжигаем токены
        _burn(from, amount);

        // Эмитируем событие для отслеживания
        emit TokensBurned(from, amount);
    }

    /**
     * @dev Приостановка всех операций с токеном
     * Полезно в случае обнаружения уязвимостей или для технического обслуживания
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Возобновление работы контракта
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Переопределение функции _update для поддержки Pausable
     * Блокирует все переводы токенов когда контракт приостановлен
     */
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    /**
     * @dev Получение информации о максимальном предложении
     * @return Максимальное количество токенов, которое может быть выпущено
     */
    function getMaxSupply() external pure returns (uint256) {
        return MAX_SUPPLY;
    }

    /**
     * @dev Получение информации о доступном для выпуска количестве токенов
     * @return Количество токенов, которое еще можно выпустить
     */
    function getAvailableSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    /**
     * @dev Назначение роли минтера (только администратор)
     * @param account Адрес для назначения роли
     */
    function grantMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    /**
     * @dev Назначение роли бёрнера (только администратор)
     * @param account Адрес для назначения роли
     */
    function grantBurnerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BURNER_ROLE, account);
    }

    /**
     * @dev Отзыв роли минтера (только администратор)
     * @param account Адрес для отзыва роли
     */
    function revokeMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }

    /**
     * @dev Отзыв роли бёрнера (только администратор)
     * @param account Адрес для отзыва роли
     */
    function revokeBurnerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(BURNER_ROLE, account);
    }

    /**
     * @dev Проверка наличия роли минтера
     * @param account Адрес для проверки
     * @return true если у аккаунта есть роль минтера
     */
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    /**
     * @dev Проверка наличия роли бёрнера
     * @param account Адрес для проверки
     * @return true если у аккаунта есть роль бёрнера
     */
    function isBurner(address account) external view returns (bool) {
        return hasRole(BURNER_ROLE, account);
    }
}
