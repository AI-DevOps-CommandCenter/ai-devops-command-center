import type { Request, Response } from "express";

import {
  getNotifications,
  markNotificationRead,
  registerDeviceToken,
  unregisterDeviceToken
} from "../services/notification.service.js";

import { sendDbError } from "../lib/db-errors.js";

const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const allowedPlatforms = ["android", "ios", "web"] as const;

type DevicePlatform = typeof allowedPlatforms[number];

function isValidDeviceToken(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.trim().length >= 10 &&
    value.trim().length <= 4096
  );
}

// GET /api/notifications
export async function getNotificationsController(
  req: Request,
  res: Response
) {
  try {
    const client = req.userSupabase;

    if (!client) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const limitValue =
      req.query.limit === undefined ? 20 : Number(req.query.limit);

    const offsetValue =
      req.query.offset === undefined ? 0 : Number(req.query.offset);

    if (
      !Number.isInteger(limitValue) ||
      limitValue < 1 ||
      limitValue > 100 ||
      !Number.isInteger(offsetValue) ||
      offsetValue < 0
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid pagination values."
      });
    }

    const result = await getNotifications(
      client,
      limitValue,
      offsetValue
    );

    return res.status(200).json({
      success: true,
      count: result.count,
      data: result.data
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Get notifications error:",
      "Failed to retrieve notifications."
    );
  }
}

// PATCH /api/notifications/:id/read
export async function markNotificationReadController(
  req: Request,
  res: Response
) {
  try {
    const client = req.userSupabase;

    if (!client) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const id = req.params.id;

    if (typeof id !== "string" || !uuidRegex.test(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid notification ID."
      });
    }

    await markNotificationRead(client, id);

    return res.status(200).json({
      success: true,
      message: "Notification marked as read successfully."
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Mark notification read error:",
      "Failed to mark notification as read."
    );
  }
}

// POST /api/device-tokens
export async function registerDeviceTokenController(
  req: Request,
  res: Response
) {
  try {
    const client = req.userSupabase;

    if (!client) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const { device_token, platform } = req.body ?? {};

    if (!isValidDeviceToken(device_token)) {
      return res.status(400).json({
        success: false,
        message: "A valid device token is required."
      });
    }

    if (
      typeof platform !== "string" ||
      !allowedPlatforms.includes(platform as DevicePlatform)
    ) {
      return res.status(400).json({
        success: false,
        message: "Platform must be android, ios or web."
      });
    }

    const result = await registerDeviceToken(
      client,
      device_token.trim(),
      platform as DevicePlatform
    );

    return res.status(201).json({
      success: true,
      message: "Device token registered successfully.",
      data: result
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Register device token error:",
      "Failed to register device token."
    );
  }
}

// DELETE /api/device-tokens
export async function unregisterDeviceTokenController(
  req: Request,
  res: Response
) {
  try {
    const client = req.userSupabase;

    if (!client) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const { device_token } = req.body ?? {};

    if (!isValidDeviceToken(device_token)) {
      return res.status(400).json({
        success: false,
        message: "A valid device token is required."
      });
    }

    await unregisterDeviceToken(client, device_token.trim());

    return res.status(200).json({
      success: true,
      message: "Device token unregistered successfully."
    });

  } catch (error) {
    return sendDbError(
      res,
      error,
      "Unregister device token error:",
      "Failed to unregister device token."
    );
  }
}