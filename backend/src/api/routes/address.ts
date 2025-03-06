import express from 'express';
import { AIServiceManager } from '../../services/ai/manager';
import { MapService } from '../../services/map/map-service';

const router = express.Router();

router.post('/analyze', async (req, res) => {
  try {
    const { address } = req.body;
    const aiManager = new AIServiceManager();
    const analysis = await aiManager.analyzeAddress(address);
    res.json(analysis);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router; 