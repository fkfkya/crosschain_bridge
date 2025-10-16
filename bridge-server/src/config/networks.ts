export interface NetworkConfig {
  name: string;
  rpcUrl: string;
  chainId: number;
  bridgeAddress?: string;
  tokenAddress?: string;
  blockExplorer?: string;
}

export const networks: Record<string, NetworkConfig> = {
  local: {
    name: 'Local Anvil',
    rpcUrl: 'http://localhost:8545',
    chainId: 31337,
    bridgeAddress: '0x993E33dc6396FE83fa955DE4C22048762F724923',
    tokenAddress: '0x29d011dC09366320EAf8e52F59D19b5d6e58a10A',
    blockExplorer: 'http://localhost:8545'
  },
  sepolia: {
    name: 'Sepolia Testnet',
    rpcUrl: process.env.SEPOLIA_RPC_URL || 'https://sepolia.infura.io/v3/YOUR_INFURA_KEY',
    chainId: 11155111,
    bridgeAddress: process.env.SEPOLIA_BRIDGE_ADDRESS,
    tokenAddress: process.env.SEPOLIA_TOKEN_ADDRESS,
    blockExplorer: 'https://sepolia.etherscan.io'
  },
  bnb_testnet: {
    name: 'BSC Testnet',
    rpcUrl: process.env.BSC_TESTNET_RPC_URL || 'https://data-seed-prebsc-1-s1.binance.org:8545/',
    chainId: 97,
    bridgeAddress: process.env.BSC_TESTNET_BRIDGE_ADDRESS,
    tokenAddress: process.env.BSC_TESTNET_TOKEN_ADDRESS,
    blockExplorer: 'https://testnet.bscscan.com'
  }
};

export function getNetworkConfig(networkName: string): NetworkConfig {
  const config = networks[networkName];
  if (!config) {
    throw new Error(`Network configuration not found for: ${networkName}`);
  }
  return config;
}

export function getAllNetworks(): NetworkConfig[] {
  return Object.values(networks);
}
