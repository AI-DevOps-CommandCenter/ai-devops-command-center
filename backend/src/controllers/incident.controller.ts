
import type { Request, Response } from "express";
import { createAuditLog } from "../services/audit.service.js";

import {
  createIncident,
  getIncidents,
  getIncidentById,
  updateIncident,
  type UpdateIncidentInput,
  type IncidentStatus,
  type IncidentSeverity
} from "../services/incident.service.js";

// Check whether the request body is a valid JSON object
function isValidBody(
  body: unknown
): body is Record<string, unknown> {
  return (
    typeof body === "object" &&
    body !== null &&
    !Array.isArray(body)
  );
}

// Validate incident UUID
function isValidUUID(id: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
}

const allowedStatuses: IncidentStatus[] = [
  "open",
  "investigating",
  "awaiting_approval",
  "remediating",
  "resolved",
  "closed"
];

const allowedSeverities: IncidentSeverity[] = [
  "low",
  "medium",
  "high",
  "critical"
];

// Create a new incident
export async function createIncidentController(
  req: Request,
  res: Response
) {
  try {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    if (!isValidBody(req.body)) {
      return res.status(400).json({
        success: false,
        message: "A valid JSON request body is required."
      });
    }

    const {
      title,
      description,
      service_name,
      environment,
      severity
    } = req.body;

    if (
      typeof title !== "string" ||
      !title.trim() ||
      typeof service_name !== "string" ||
      !service_name.trim() ||
      typeof severity !== "string" ||
      !allowedSeverities.includes(severity as IncidentSeverity)
    ) {
      return res.status(400).json({
        success: false,
        message: "Title, service name and a valid severity are required."
      });
    }

    if (
      description !== undefined &&
      typeof description !== "string"
    ) {
      return res.status(400).json({
        success: false,
        message: "Description must be a string."
      });
    }

    if (
      environment !== undefined &&
      typeof environment !== "string"
    ) {
      return res.status(400).json({
        success: false,
        message: "Environment must be a string."
      });
    }

    const incidentData = {
      title: title.trim(),
      description,
      service_name: service_name.trim(),
      environment,
      severity: severity as IncidentSeverity
    };

    const { data, error } = await createIncident(
      req.userSupabase,
      incidentData,
      req.user.id
    );

    if (error) {
      console.error("Create incident error:", error);

      return res.status(400).json({
        success: false,
        message: "Unable to create incident."
      });
    }
    // Record incident creation in the audit log
    try {
      await createAuditLog(
        req.userSupabase,
        {
          action: "INCIDENT_CREATED",
          entity_type: "incident",
          entity_id: data.id,
          details: {
            title: data.title,
            service_name: data.service_name,
            severity: data.severity
          }
        },
        req.user.id
      );
    } catch (auditError) {
      console.error("Incident creation audit log error:", auditError);
    }

    return res.status(201).json({
      success: true,
      message: "Incident created successfully.",
      data
    });

  } catch (error) {
    console.error("Create incident controller error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error."
    });
  }
}

// Retrieve all incidents with optional filters
export async function getIncidentsController(
  req: Request,
  res: Response
) {
  try {
    if (!req.userSupabase) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const status =
      typeof req.query.status === "string"
        ? req.query.status
        : undefined;

    const severity =
      typeof req.query.severity === "string"
        ? req.query.severity
        : undefined;

    const service_name =
      typeof req.query.service_name === "string"
        ? req.query.service_name
        : undefined;

    const limitValue =
      typeof req.query.limit === "string"
        ? Number(req.query.limit)
        : 20;

    const offsetValue =
      typeof req.query.offset === "string"
        ? Number(req.query.offset)
        : 0;

    if (
      !Number.isInteger(limitValue) ||
      !Number.isInteger(offsetValue) ||
      limitValue < 1 ||
      limitValue > 100 ||
      offsetValue < 0
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid pagination values."
      });
    }

    if (status && !allowedStatuses.includes(status as IncidentStatus)) {
      return res.status(400).json({
        success: false,
        message: "Invalid incident status."
      });
    }

    if (severity && !allowedSeverities.includes(severity as IncidentSeverity)) {
      return res.status(400).json({
        success: false,
        message: "Invalid incident severity."
      });
    }

    const { data, error } = await getIncidents(
      req.userSupabase,
      {
        status,
        severity: severity as IncidentSeverity | undefined,
        service_name,
        limit: limitValue,
        offset: offsetValue
      }
    );

    if (error) {
      console.error("Get incidents error:", error);

      return res.status(500).json({
        success: false,
        message: "Unable to retrieve incidents."
      });
    }

    return res.status(200).json({
      success: true,
      count: data?.length ?? 0,
      data
    });

  } catch (error) {
    console.error("Get incidents controller error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error."
    });
  }
}

// Retrieve one incident by ID
export async function getIncidentByIdController(
  req: Request,
  res: Response
) {
  try {
    if (!req.userSupabase) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const incidentId = Array.isArray(req.params.id)
      ? req.params.id[0]
      : req.params.id;

    if (!incidentId) {
      return res.status(400).json({
        success: false,
        message: "Incident ID is required."
      });
    }

    if (!isValidUUID(incidentId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid incident ID."
      });
    }

    const { data, error } = await getIncidentById(
      req.userSupabase,
      incidentId
    );

    if (error) {
      if (error.code === "PGRST116") {
        return res.status(404).json({
          success: false,
          message: "Incident not found."
        });
      }

      console.error("Get incident error:", error);

      return res.status(500).json({
        success: false,
        message: "Unable to retrieve incident."
      });
    }

    return res.status(200).json({
      success: true,
      data
    });

  } catch (error) {
    console.error("Get incident controller error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error."
    });
  }
}

// Update an existing incident
export async function updateIncidentController(
  req: Request,
  res: Response
) {
  try {
    if (!req.user || !req.userSupabase) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    const incidentId = Array.isArray(req.params.id)
      ? req.params.id[0]
      : req.params.id;

    if (!incidentId) {
      return res.status(400).json({
        success: false,
        message: "Incident ID is required."
      });
    }

    if (!isValidUUID(incidentId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid incident ID."
      });
    }

    // Prevent destructuring an undefined or invalid request body
    if (!isValidBody(req.body)) {
      console.log("PATCH Content-Type:", req.headers["content-type"]);
      console.log("PATCH request body:", req.body);

      return res.status(400).json({
        success: false,
        message: "A valid JSON request body is required."
      });
    }

    const {
      title,
      description,
      service_name,
      environment,
      severity,
      status
    } = req.body;

    const updates: UpdateIncidentInput = {};

    // Validate title
    if (title !== undefined) {
      if (typeof title !== "string" || !title.trim()) {
        return res.status(400).json({
          success: false,
          message: "Title must be a non-empty string."
        });
      }

      updates.title = title.trim();
    }

    // Validate description
    if (description !== undefined) {
      if (typeof description !== "string") {
        return res.status(400).json({
          success: false,
          message: "Description must be a string."
        });
      }

      updates.description = description;
    }

    // Validate service name
    if (service_name !== undefined) {
      if (
        typeof service_name !== "string" ||
        !service_name.trim()
      ) {
        return res.status(400).json({
          success: false,
          message: "Service name must be a non-empty string."
        });
      }

      updates.service_name = service_name.trim();
    }

    // Validate environment
    if (environment !== undefined) {
      if (typeof environment !== "string") {
        return res.status(400).json({
          success: false,
          message: "Environment must be a string."
        });
      }

      updates.environment = environment;
    }

    // Validate severity
    if (severity !== undefined) {
      if (
        typeof severity !== "string" ||
        !allowedSeverities.includes(severity as IncidentSeverity)
      ) {
        return res.status(400).json({
          success: false,
          message: "Invalid incident severity."
        });
      }

      updates.severity = severity as IncidentSeverity;
    }

    // Validate status
    if (status !== undefined) {
      if (
        typeof status !== "string" ||
        !allowedStatuses.includes(status as IncidentStatus)
      ) {
        return res.status(400).json({
          success: false,
          message: "Invalid incident status."
        });
      }

      updates.status = status as IncidentStatus;
    }

    // Reject an empty update
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        success: false,
        message: "No valid fields provided for update."
      });
    }

    const { data, error } = await updateIncident(
      req.userSupabase,
      incidentId,
      updates
    );

    if (error) {
      if (error.code === "PGRST116") {
        return res.status(404).json({
          success: false,
          message: "Incident not found."
        });
      }

      console.error("Update incident error:", error);

      return res.status(500).json({
        success: false,
        message: "Unable to update incident."
      });
    }
    // Record incident update in the audit log
    try {
      await createAuditLog(
        req.userSupabase,
        {
          action: "INCIDENT_UPDATED",
          entity_type: "incident",
          entity_id: incidentId,
          details: {
            updated_fields: updates
          }
        },
        req.user.id
      );
    } catch (auditError) {
      console.error("Incident update audit log error:", auditError);
    }

    return res.status(200).json({
      success: true,
      message: "Incident updated successfully.",
      data
    });

  } catch (error) {
    console.error("Update incident controller error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error."
    });
  }
}
