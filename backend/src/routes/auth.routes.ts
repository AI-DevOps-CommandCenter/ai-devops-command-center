import { Router } from "express";
import { z } from "zod";
import { supabasePublic } from "../lib/supabase-public";

const router = Router();

// Public Supabase configuration
router.get("/config", (_req, res) => {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    return res.status(500).json({
      success: false,
      message: "Supabase configuration is missing.",
    });
  }

  return res.status(200).json({
    supabaseUrl,
    supabaseAnonKey,
  });
});

// Validate the email address
const forgotPasswordSchema = z.object({
  email: z.string().email("Please enter a valid email address."),
});

// POST /api/auth/forgot-password
router.post("/forgot-password", async (req, res) => {
  try {
    const validation = forgotPasswordSchema.safeParse(req.body);

    if (!validation.success) {
      return res.status(400).json({
        success: false,
        message: "Please provide a valid email address.",
      });
    }

    const { email } = validation.data;

    const { error } = await supabasePublic.auth.resetPasswordForEmail(
      email,
      {
        redirectTo: "http://localhost:3000/reset-password",
      }
    );

    if (error) {
      console.error("Password recovery request failed:", error.message);

      return res.status(400).json({
        success: false,
        message: "Unable to process password recovery request.",
      });
    }

    return res.status(200).json({
      success: true,
      message:
        "If an account exists for this email, a password recovery email will be sent.",
    });
  } catch (error) {
    console.error("Forgot password error:", error);

    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred.",
    });
  }
});

export default router;