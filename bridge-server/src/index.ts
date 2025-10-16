import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { logger } from './utils/logger';
import { BridgeService } from './services/BridgeService';
import { BlockchainService } from './services/BlockchainService';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true
}));
app.use(express.json());

// Initialize services
const blockchainService = new BlockchainService();
const bridgeService = new BridgeService(blockchainService);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    service: 'crosschain-bridge-server'
  });
});

// Get bridge status
app.get('/bridge/status', async (req, res) => {
  try {
    const status = await bridgeService.getBridgeStatus();
    res.json(status);
  } catch (error) {
    logger.error('Error getting bridge status:', error);
    res.status(500).json({ error: 'Failed to get bridge status' });
  }
});

// Get recent events
app.get('/bridge/events', async (req, res) => {
  try {
    const events = await bridgeService.getRecentEvents();
    res.json(events);
  } catch (error) {
    logger.error('Error getting recent events:', error);
    res.status(500).json({ error: 'Failed to get recent events' });
  }
});

// Start server
app.listen(PORT, () => {
  logger.info(`🚀 Cross-chain bridge server started on port ${PORT}`);
  logger.info(`📊 Health check: http://localhost:${PORT}/health`);
  logger.info(`🌉 Bridge status: http://localhost:${PORT}/bridge/status`);
  logger.info(`📋 Recent events: http://localhost:${PORT}/bridge/events`);
  
  // Start monitoring events
  bridgeService.startEventMonitoring();
});

// Graceful shutdown
process.on('SIGINT', () => {
  logger.info('🛑 Shutting down server...');
  bridgeService.stopEventMonitoring();
  process.exit(0);
});

process.on('SIGTERM', () => {
  logger.info('🛑 Shutting down server...');
  bridgeService.stopEventMonitoring();
  process.exit(0);
});
