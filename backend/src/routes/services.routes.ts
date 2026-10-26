import { Router } from "express";
import { z } from "zod";
import { supabase } from "../lib/supabase";
import { requireAuth, requireRole } from "../middleware/auth";

const router = Router();

// Require authentication for every services endpoint.
router.use(requireAuth);

const createServiceSchema = z.object({
name: z.string().trim().min(1).max(200),
description: z.string().max(2000).nullable().optional(),
environment: z.enum([
"development",
"testing",
"staging",
"production",
]),
endpoint: z.string().url().nullable().optional(),
status: z.enum([
"healthy",
"degraded",
"down",
"unknown",
]).optional(),
});

// GET /api/services
// Any authenticated user with a valid profile can view services.
router.get("/", async (_req, res) => {
try {
const { data, error } = await supabase
.from("services")
.select("*")
.order("created_at", { ascending: false });


if (error) {
  console.error("Failed to fetch services:", error.message);

  return res.status(500).json({
    success: false,
    message: "Failed to fetch services",
  });
}

return res.status(200).json({
  success: true,
  count: data.length,
  data,
});


} catch (error) {
console.error("Unexpected error while fetching services:", error);


return res.status(500).json({
  success: false,
  message: "An unexpected error occurred",
});


}
});

// POST /api/services
// Only admins and operators can create services.
router.post(
"/",
requireRole("admin", "operator"),
async (req, res) => {
const validation = createServiceSchema.safeParse(req.body);


if (!validation.success) {
  return res.status(400).json({
    success: false,
    message: "Invalid service data",
    errors: validation.error.issues.map((issue) => ({
      field: issue.path.join("."),
      message: issue.message,
    })),
  });
}

try {
  const serviceData = {
    ...validation.data,
    description: validation.data.description ?? null,
    endpoint: validation.data.endpoint ?? null,
    status: validation.data.status ?? "unknown",
  };

  const { data, error } = await supabase
    .from("services")
    .insert(serviceData)
    .select("*")
    .single();

  if (error) {
    console.error("Failed to create service:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to create service",
    });
  }

  return res.status(201).json({
    success: true,
    message: "Service created successfully",
    data,
  });
} catch (error) {
  console.error("Unexpected error while creating service:", error);

  return res.status(500).json({
    success: false,
    message: "An unexpected error occurred",
  });
}


}
);

// PATCH /api/services/:id
// Only admins and operators can update services.
const updateServiceSchema = createServiceSchema
.partial()
.refine(
(data) => Object.keys(data).length > 0,
{
message: "At least one field is required to update",
}
);

router.patch(
"/:id",
requireRole("admin", "operator"),
async (req, res) => {
const { id } = req.params;


const uuidSchema = z.string().uuid();

if (!uuidSchema.safeParse(id).success) {
  return res.status(400).json({
    success: false,
    message: "Invalid service ID",
  });
}

const validation = updateServiceSchema.safeParse(req.body);

if (!validation.success) {
  return res.status(400).json({
    success: false,
    message: "Invalid service data",
    errors: validation.error.issues.map((issue) => ({
      field: issue.path.join("."),
      message: issue.message,
    })),
  });
}

try {
  const { data, error } = await supabase
    .from("services")
    .update({
      ...validation.data,
      updated_at: new Date().toISOString(),
    })
    .eq("id", id)
    .select("*")
    .maybeSingle();

  if (error) {
    console.error("Failed to update service:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to update service",
    });
  }

  if (!data) {
    return res.status(404).json({
      success: false,
      message: "Service not found",
    });
  }

  return res.status(200).json({
    success: true,
    message: "Service updated successfully",
    data,
  });
} catch (error) {
  console.error("Unexpected error while updating service:", error);

  return res.status(500).json({
    success: false,
    message: "An unexpected error occurred",
  });
}


}
);

// GET /api/services/:id
// Any authenticated user with a valid profile can view one service.
router.get("/:id", async (req, res) => {
const { id } = req.params;

const uuidSchema = z.string().uuid();

if (!uuidSchema.safeParse(id).success) {
return res.status(400).json({
success: false,
message: "Invalid service ID",
});
}

try {
const { data, error } = await supabase
.from("services")
.select("*")
.eq("id", id)
.maybeSingle();


if (error) {
  console.error("Failed to fetch service:", error.message);

  return res.status(500).json({
    success: false,
    message: "Failed to fetch service",
  });
}

if (!data) {
  return res.status(404).json({
    success: false,
    message: "Service not found",
  });
}

return res.status(200).json({
  success: true,
  data,
});


} catch (error) {
console.error("Unexpected error while fetching service:", error);


return res.status(500).json({
  success: false,
  message: "An unexpected error occurred",
});


}
});

// DELETE /api/services/:id
// Only admins and operators can delete services.
router.delete(
"/:id",
requireRole("admin", "operator"),
async (req, res) => {
const { id } = req.params;


const uuidSchema = z.string().uuid();

if (!uuidSchema.safeParse(id).success) {
  return res.status(400).json({
    success: false,
    message: "Invalid service ID",
  });
}

try {
  const { data, error } = await supabase
    .from("services")
    .delete()
    .eq("id", id)
    .select("id, name")
    .maybeSingle();

  if (error) {
    console.error("Failed to delete service:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to delete service",
    });
  }

  if (!data) {
    return res.status(404).json({
      success: false,
      message: "Service not found",
    });
  }

  return res.status(200).json({
    success: true,
    message: "Service deleted successfully",
    data,
  });
} catch (error) {
  console.error("Unexpected error while deleting service:", error);

  return res.status(500).json({
    success: false,
    message: "An unexpected error occurred",
  });
}


}
);

export default router;
