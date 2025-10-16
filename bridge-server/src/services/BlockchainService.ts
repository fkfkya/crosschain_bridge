import { ethers } from 'ethers';
import { logger } from '../utils/logger';
import { NetworkConfig, getNetworkConfig } from '../config/networks';

export class BlockchainService {
  private providers: Map<string, ethers.JsonRpcProvider> = new Map();
  private wallets: Map<string, ethers.Wallet> = new Map();

  constructor() {
    this.initializeProviders();
    this.initializeWallets();
  }

  private initializeProviders(): void {
    const networks = ['local', 'sepolia', 'bnb_testnet'];
    
    for (const networkName of networks) {
      try {
        const config = getNetworkConfig(networkName);
        const provider = new ethers.JsonRpcProvider(config.rpcUrl);
        this.providers.set(networkName, provider);
        logger.info(`✅ Connected to ${config.name} (${config.chainId})`);
      } catch (error) {
        logger.warn(`⚠️ Failed to connect to ${networkName}:`, error);
      }
    }
  }

  private initializeWallets(): void {
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) {
      logger.warn('⚠️ No private key found in environment variables');
      return;
    }

    for (const [networkName, provider] of this.providers) {
      try {
        const wallet = new ethers.Wallet(privateKey, provider);
        this.wallets.set(networkName, wallet);
        logger.info(`✅ Wallet initialized for ${networkName}: ${wallet.address}`);
      } catch (error) {
        logger.error(`❌ Failed to initialize wallet for ${networkName}:`, error);
      }
    }
  }

  getProvider(networkName: string): ethers.JsonRpcProvider {
    const provider = this.providers.get(networkName);
    if (!provider) {
      throw new Error(`Provider not found for network: ${networkName}`);
    }
    return provider;
  }

  getWallet(networkName: string): ethers.Wallet {
    const wallet = this.wallets.get(networkName);
    if (!wallet) {
      throw new Error(`Wallet not found for network: ${networkName}`);
    }
    return wallet;
  }

  async getBalance(networkName: string, address: string): Promise<string> {
    const provider = this.getProvider(networkName);
    const balance = await provider.getBalance(address);
    return ethers.formatEther(balance);
  }

  async getBlockNumber(networkName: string): Promise<number> {
    const provider = this.getProvider(networkName);
    return await provider.getBlockNumber();
  }

  async getNetworkInfo(networkName: string): Promise<any> {
    const provider = this.getProvider(networkName);
    const network = await provider.getNetwork();
    const blockNumber = await provider.getBlockNumber();
    
    return {
      name: networkName,
      chainId: Number(network.chainId),
      blockNumber,
      network: network
    };
  }

  async getAllNetworksInfo(): Promise<any[]> {
    const networks = ['local', 'sepolia', 'bnb_testnet'];
    const results = [];

    for (const networkName of networks) {
      try {
        const info = await this.getNetworkInfo(networkName);
        results.push(info);
      } catch (error) {
        logger.warn(`Failed to get info for ${networkName}:`, error);
        results.push({
          name: networkName,
          error: error instanceof Error ? error.message : 'Unknown error'
        });
      }
    }

    return results;
  }
}
