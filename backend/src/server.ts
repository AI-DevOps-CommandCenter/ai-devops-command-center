import express from "express";
import cors from "cors";
import helmet from "helmet";
import dotenv from "dotenv";
import path from "path";

import servicesRouter from "./routes/services.routes";
import authRouter from "./routes/auth.routes";

dotenv.config();

const app = express();
const PORT = Number(process.env.PORT) || 3000;

// Security and request middleware
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        ...helmet.contentSecurityPolicy.getDefaultDirectives(),

        // Allow Supabase JavaScript SDK from jsDelivr CDN
        "script-src": [
          "'self'",
          "https://cdn.jsdelivr.net",
        ],

        // Allow communication with Supabase
        "connect-src": [
          "'self'",
          "https://hjqvjztbsndgyooyadup.supabase.co",
          "wss://hjqvjztbsndgyooyadup.supabase.co",
        ],
      },
    },
  })
);

app.use(cors());
app.use(express.json());

// Password reset page
app.get("/reset-password", (_req, res) => {
  res.sendFile(
    path.join(process.cwd(), "public", "reset-password.html")
  );
});

// Serve static frontend files
app.use(express.static(path.join(process.cwd(), "public")));

// Health check endpoint
app.get("/health", (_req, res) => {
  res.status(200).json({
    success: true,
    message: "DevOps Command Center API is running",
    timestamp: new Date().toISOString(),
  });
});

// Authentication API routes
app.use("/api/auth", authRouter);

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