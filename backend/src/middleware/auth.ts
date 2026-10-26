import type { RequestHandler } from "express";
import { supabase } from "../lib/supabase";

const allowedRoles = ["user", "admin", "operator"] as const;

export const requireAuth: RequestHandler = async (req, res, next) => {
const authorization = req.header("authorization");

if (!authorization?.startsWith("Bearer ")) {
res.status(401).json({
success: false,
message: "Authentication required.",
});
return;
}

const token = authorization.slice(7).trim();

if (!token) {
res.status(401).json({
success: false,
message: "Access token is missing.",
});
return;
}

try {
const { data, error } = await supabase.auth.getUser(token);

if (error || !data.user) {
  res.status(401).json({
    success: false,
    message: "Invalid or expired access token.",
  });
  return;
}

const { data: profile, error: profileError } = await supabase
  .from("profiles")
  .select("role")
  .eq("id", data.user.id)
  .maybeSingle();

if (profileError) {
  console.error("Failed to retrieve user profile:", profileError.message);
  res.status(500).json({
    success: false,
    message: "Unable to verify user permissions.",
  });
  return;
}

if (
  !profile ||
  !allowedRoles.includes(profile.role as (typeof allowedRoles)[number])
) {
  res.status(403).json({
    success: false,
    message: "User profile or valid role not found.",
  });
  return;
}

res.locals.authUser = data.user;
res.locals.userRole = profile.role;
next();

} catch (error) {
console.error("Authentication middleware error:", error);
res.status(500).json({
success: false,
message: "An unexpected authentication error occurred.",
});
}
};

export const requireRole = (
...roles: Array<"user" | "admin" | "operator">
): RequestHandler => {
return (_req, res, next) => {
const userRole = res.locals.userRole;

if (!roles.includes(userRole)) {
  res.status(403).json({
    success: false,
    message: "You do not have permission to perform this action.",
  });
  return;
}

next();

};
};
