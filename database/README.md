# Database

## Project Overview

The database stores and manages the information required by the AI-Powered Mobile DevOps Command Center.

The project uses Supabase, which provides PostgreSQL database services and authentication integration.

## Database Responsibilities

The database supports the following features:

* Incident management and tracking.
* Service and deployment management.
* AI-generated incident analysis and recommendations.
* Controlled remediation through playbooks.
* Recovery verification.
* Notifications for users.
* Audit logging and post-incident documentation.
* User profiles and device token management.

## Database Tables

The database currently contains the following 12 tables:

| Table             | Purpose                                                   |
| ----------------- | --------------------------------------------------------- |
| `profiles`        | Stores application user profiles and roles.               |
| `services`        | Stores information about monitored services.              |
| `deployments`     | Tracks service deployments and their statuses.            |
| `incidents`       | Stores incidents and their current statuses.              |
| `ai_analyses`     | Stores AI analysis results and recommended actions.       |
| `playbooks`       | Defines the available remediation actions.                |
| `playbook_runs`   | Tracks remediation requests and execution statuses.       |
| `recovery_checks` | Stores incident recovery verification results.            |
| `notifications`   | Stores notifications associated with users and incidents. |
| `device_tokens`   | Stores device tokens associated with user accounts.       |
| `audit_log`       | Records relevant audit events.                            |
| `postmortems`     | Stores post-incident reviews and findings.                |

## Security

The database uses PostgreSQL Row Level Security (RLS) on all 12 tables.

Database security includes:

* User authentication through Supabase Auth.
* Role-based authorization in the backend.
* RLS policies for selected authenticated-user operations.
* Foreign-key constraints to maintain relationships between records.
* Check constraints to validate supported statuses and remediation action types.
* Server-side use of the Supabase service-role key.

**Important:** The service-role key bypasses RLS. It must remain on the backend and must never be exposed in frontend code or committed to the repository. Backend endpoints must enforce authentication and authorization before performing protected operations.

RLS being enabled does not, by itself, guarantee that every operation is secure. Database permissions, policies, functions, and backend authorization must be reviewed together.

## Supported Remediation Actions

The currently supported remediation action types are:

* `restart`
* `rollback`
* `scale`
* `circuit_breaker`

Playbooks are currently disabled, and approval is required by the existing playbook configuration. They must not be enabled for execution until the backend implements and verifies the required authorization and approval controls.

## Database Migrations

Database changes should be maintained through reviewed SQL migration files.

Before applying a migration:

1. Review the SQL changes.
2. Confirm that the changes match the approved project design.
3. Apply the migration to the intended environment.
4. Verify the resulting schema, constraints, and policies.
5. Record the migration in the repository.

Do not reapply an existing migration without first checking whether its changes have already been applied.

## Environment Variables

Database connection settings must be stored in environment variables.

The backend requires:

* `SUPABASE_URL`
* `SUPABASE_SERVICE_ROLE_KEY`

The `.env` file must not be committed to Git. Use a safe example configuration file when documenting the required variable names.

Never include real credentials, access tokens, or secret keys in this documentation.

## Testing and Development Status

The current database structure, RLS policies, selected permissions, triggers, and constraints have been inspected during development.

Backend unit tests and TypeScript type checking have passed.

Live database integration testing and the remaining security verification must be completed before considering the database integration production-ready.
