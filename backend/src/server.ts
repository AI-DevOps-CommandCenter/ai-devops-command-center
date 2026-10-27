
import express from "express";
import cors from "cors";
import helmet from "helmet";
import dotenv from "dotenv";
import servicesRouter from "./routes/services.routes";

dotenv.config();

const app = express();
const PORT = Number(process.env.PORT) || 3000;

// Security and request middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get("/health", (_req, res) => {
  res.status(200).json({
    success: true,
    message: "DevOps Command Center API is running",
    timestamp: new Date().toISOString(),
  });
});

// Services API routes
app.use("/api/services", servicesRouter);

// Export app for automated testing
export default app;

// Start server only when this file is executed directly
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`API server running at http://localhost:${PORT}`);
  });
}
