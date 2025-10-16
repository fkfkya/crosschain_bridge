# Cross-Chain Bridge Project

## Описание

Данный проект реализует кроссчейн мост для перевода токенов между различными блокчейн сетями. Проект состоит из смарт-контрактов на Solidity и сервера на Node.js для обработки событий и координации переводов.

## Архитектура

### Смарт-контракты

1. **BridgeToken.sol** - ERC20 токен с функциями mint и burn
   - Наследует стандартный ERC20 от OpenZeppelin
   - Добавляет функции mint (выпуск) и burn (сжигание) токенов
   - Использует роли для контроля доступа
   - Поддерживает Pausable для экстренной остановки

2. **CrossChainBridge.sol** - основной контракт моста
   - Блокирует токены в исходной сети (burn)
   - Разблокирует токены в целевой сети (mint)
   - Защита от повторной обработки через nonce
   - Подпись валидатора для авторизации
   - События для отслеживания операций

### Сервер

3. **Bridge Server** - Node.js сервер для координации переводов
   - Отслеживает события TokensLocked
   - Подписывает операции разблокировки
   - Вызывает unlockTokens в целевой сети

## Структура проекта

```
crosschain_bridge/
├── src/                    # Смарт-контракты
│   ├── BridgeToken.sol
│   └── CrossChainBridge.sol
├── script/                 # Скрипты деплоя
│   ├── DeployBridge.s.sol
│   ├── DeployToken.s.sol
│   └── TestCrossChainTransfer.s.sol
├── test/                   # Тесты
│   └── CrossChainBridgeIntegration.t.sol
├── bridge-server/          # Сервер моста
│   ├── src/
│   │   ├── config/
│   │   └── services/
│   └── package.json
└── lib/                    # Зависимости
    ├── forge-std/
    └── openzeppelin-contracts/
```

## Требования

- Foundry
- Node.js
- npm

## Установка

1. Клонируйте репозиторий
2. Установите зависимости Foundry:
```bash
git submodule update --init --recursive
```
3. Установите зависимости сервера:
```bash
cd bridge-server
npm install
```

## Пошаговый план тестирования

### Пункт 1: Юнит-тесты для контракта моста (2 балла)

#### 1.1 Запуск тестов
```bash
forge test
```

#### 1.2 Проверка покрытия
```bash
forge coverage
```

#### 1.3 Детальный вывод тестов
```bash
forge test -vvv
```

**Ожидаемый результат:**
- Все 4 теста проходят успешно
- testDeployFourContracts - деплой 2 мостов + 2 токенов
- testCallDepositFunction - вызов функции депозита
- testEventVerification - проверка события
- testMintTokensInSecondContract - чеканка токенов

### Пункт 2: Тестирование в локальной сети (2 балла)

#### 2.1 Развертывание тестовой сети
```bash
anvil
```

#### 2.2 Настройка переменных окружения
Создайте файл .env:
```
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
VALIDATOR_ADDRESS=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
NETWORK_NAME=anvil
```

#### 2.3 Запуск сервера
```bash
cd bridge-server
npm start
```

#### 2.4 Развертывание контрактов
```bash
forge script script/DeployBridge.s.sol --rpc-url http://localhost:8545 --broadcast
```

#### 2.5 Проверка деплоя
```bash
curl http://localhost:3000/bridge/status
```

#### 2.6 Депозит + сжигание токенов
```bash
forge script script/TestCrossChainTransfer.s.sol --rpc-url http://localhost:8545 --broadcast
```

#### 2.7 Проверка получения события сервером
```bash
curl http://localhost:3000/bridge/events
```

**Ожидаемый результат:**
- Сервер получает событие TokensLocked
- Токены сжигаются в исходной сети
- Готовность к разблокировке в целевой сети

## Команды для проверки

### Проверка баланса токенов
```bash
cast call <token_address> "balanceOf(address)" <user_address> --rpc-url http://localhost:8545
```

### Проверка информации о мосте
```bash
cast call <bridge_address> "getBridgeInfo()" --rpc-url http://localhost:8545
```

### Проверка использования nonce
```bash
cast call <bridge_address> "isNonceUsed(uint256)" <nonce> --rpc-url http://localhost:8545
```

## Форматирование кода

```bash
forge fmt
```

## Сборка проекта

```bash
forge build
```

## Логи сервера

Логи сервера сохраняются в папке `bridge-server/logs/`:
- combined.log - все логи
- error.log - только ошибки