import { ethers } from 'ethers';
import { logger } from '../utils/logger';
import { BlockchainService } from './BlockchainService';
import { getNetworkConfig } from '../config/networks';

export interface BridgeEvent {
  network: string;
  blockNumber: number;
  transactionHash: string;
  eventName: string;
  args: any;
  timestamp: Date;
}

export class BridgeService {
  private blockchainService: BlockchainService;
  private eventMonitoring: Map<string, NodeJS.Timeout> = new Map();
  private recentEvents: BridgeEvent[] = [];
  private readonly MAX_EVENTS = 100;

  constructor(blockchainService: BlockchainService) {
    this.blockchainService = blockchainService;
  }

  startEventMonitoring(): void {
    logger.info('🔍 Starting event monitoring...');
    
    // Monitor local network
    this.monitorNetworkEvents('local');
    
    // Monitor testnets if configured
    if (process.env.SEPOLIA_BRIDGE_ADDRESS) {
      this.monitorNetworkEvents('sepolia');
    }
    
    if (process.env.BSC_TESTNET_BRIDGE_ADDRESS) {
      this.monitorNetworkEvents('bnb_testnet');
    }
  }

  stopEventMonitoring(): void {
    logger.info('🛑 Stopping event monitoring...');
    
    for (const [network, interval] of this.eventMonitoring) {
      clearInterval(interval);
      logger.info(`✅ Stopped monitoring ${network}`);
    }
    
    this.eventMonitoring.clear();
  }

  private monitorNetworkEvents(networkName: string): void {
    try {
      const config = getNetworkConfig(networkName);
      if (!config.bridgeAddress) {
        logger.warn(`⚠️ No bridge address configured for ${networkName}`);
        return;
      }

      const provider = this.blockchainService.getProvider(networkName);
      const bridgeContract = new ethers.Contract(
        config.bridgeAddress,
        this.getBridgeABI(),
        provider
      );

      // Listen for TokensLocked events
      bridgeContract.on('TokensLocked', (user, amount, nonce, sourceChainId, targetChainId, transferHash, event) => {
        this.handleTokensLockedEvent(networkName, event, {
          user,
          amount: amount.toString(),
          nonce: nonce.toString(),
          sourceChainId: sourceChainId.toString(),
          targetChainId: targetChainId.toString(),
          transferHash
        });
      });

      // Listen for TokensUnlocked events
      bridgeContract.on('TokensUnlocked', (user, amount, nonce, sourceChainId, targetChainId, transferHash, event) => {
        this.handleTokensUnlockedEvent(networkName, event, {
          user,
          amount: amount.toString(),
          nonce: nonce.toString(),
          sourceChainId: sourceChainId.toString(),
          targetChainId: targetChainId.toString(),
          transferHash
        });
      });

      logger.info(`✅ Started monitoring ${config.name} bridge events`);
    } catch (error) {
      logger.error(`❌ Failed to start monitoring ${networkName}:`, error);
    }
  }

  private handleTokensLockedEvent(networkName: string, event: any, args: any): void {
    const bridgeEvent: BridgeEvent = {
      network: networkName,
      blockNumber: event.blockNumber,
      transactionHash: event.transactionHash,
      eventName: 'TokensLocked',
      args,
      timestamp: new Date()
    };

    this.addEvent(bridgeEvent);
    
    logger.info(`🔒 Tokens locked on ${networkName}:`, {
      user: args.user,
      amount: ethers.formatEther(args.amount),
      targetChain: args.targetChainId,
      txHash: event.transactionHash
    });

    // Here you would implement the logic to unlock tokens on the target chain
    this.processTokensLockedEvent(bridgeEvent);
  }

  private handleTokensUnlockedEvent(networkName: string, event: any, args: any): void {
    const bridgeEvent: BridgeEvent = {
      network: networkName,
      blockNumber: event.blockNumber,
      transactionHash: event.transactionHash,
      eventName: 'TokensUnlocked',
      args,
      timestamp: new Date()
    };

    this.addEvent(bridgeEvent);
    
    logger.info(`🔓 Tokens unlocked on ${networkName}:`, {
      user: args.user,
      amount: ethers.formatEther(args.amount),
      sourceChain: args.sourceChainId,
      txHash: event.transactionHash
    });
  }

  private async processTokensLockedEvent(event: BridgeEvent): Promise<void> {
    try {
      // This is where you would implement the cross-chain logic
      // For now, we'll just log the event
      logger.info(`🔄 Processing tokens locked event:`, {
        network: event.network,
        user: event.args.user,
        amount: event.args.amount,
        targetChain: event.args.targetChainId
      });

      // In a real implementation, you would:
      // 1. Verify the event
      // 2. Create a signature
      // 3. Call unlockTokens on the target chain
      
    } catch (error) {
      logger.error('❌ Error processing tokens locked event:', error);
    }
  }

  private addEvent(event: BridgeEvent): void {
    this.recentEvents.unshift(event);
    
    // Keep only the most recent events
    if (this.recentEvents.length > this.MAX_EVENTS) {
      this.recentEvents = this.recentEvents.slice(0, this.MAX_EVENTS);
    }
  }

  getRecentEvents(): BridgeEvent[] {
    return this.recentEvents;
  }

  async getBridgeStatus(): Promise<any> {
    const networks = ['local', 'sepolia', 'bnb_testnet'];
    const status: any = {
      timestamp: new Date().toISOString(),
      networks: {},
      totalEvents: this.recentEvents.length
    };

    for (const networkName of networks) {
      try {
        const networkInfo = await this.blockchainService.getNetworkInfo(networkName);
        const config = getNetworkConfig(networkName);
        
        status.networks[networkName] = {
          ...networkInfo,
          bridgeAddress: config.bridgeAddress,
          tokenAddress: config.tokenAddress,
          isConnected: true
        };
      } catch (error) {
        status.networks[networkName] = {
          name: networkName,
          isConnected: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        };
      }
    }

    return status;
  }

  private getBridgeABI(): any[] {
    // Simplified ABI for the bridge contract
    return [
      "event TokensLocked(address indexed user, uint256 amount, uint256 nonce, uint256 indexed sourceChainId, uint256 indexed targetChainId, bytes32 transferHash)",
      "event TokensUnlocked(address indexed user, uint256 amount, uint256 nonce, uint256 indexed sourceChainId, uint256 indexed targetChainId, bytes32 transferHash)",
      "function lockTokens(uint256 amount, uint256 targetChainId) external",
      "function unlockTokens(address user, uint256 amount, uint256 nonce, uint256 sourceChainId, bytes memory signature) external"
    ];
  }
}
