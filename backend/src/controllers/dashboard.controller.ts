import type { Request, Response } from "express";
import { getDashboardSummary } from "../services/dashboard.service.js";

// Get dashboard summary
export async function getDashboardSummaryController(
  req: Request,
  res: Response
) {
  try {
    // Check authentication
    if (!req.userSupabase) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    // Retrieve dashboard statistics
    const { data, error } = await getDashboardSummary(
      req.userSupabase
    );

    // Handle database errors
    if (error) {
      console.error("Dashboard summary error:", error);

      return res.status(500).json({
        success: false,
        message: "Unable to retrieve dashboard summary."
      });
    }

    // Return dashboard statistics
    return res.status(200).json({
      success: true,
      message: "Dashboard summary retrieved successfully.",
      data
    });

  } catch (error) {
    console.error("Dashboard controller error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error."
    });
  }
}