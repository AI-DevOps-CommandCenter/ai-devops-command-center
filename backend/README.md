
# AI-Powered Mobile DevOps Command Center - Backend

## 1. Overview

The backend provides REST APIs and business logic connecting the Flutter mobile application with Supabase authentication and database services.

It manages incidents, investigations, approvals, playbook executions, remediation records, audit logs, postmortems, and dashboard information.

## 2. Technology Stack

- Node.js
- Express.js
- TypeScript
- Supabase (PostgreSQL and Authentication)
- REST API
- npm

## 3. Project Structure

```text
backend/
├── src/
│   ├── config/
│   ├── controllers/
│   ├── middleware/
│   ├── routes/
│   ├── services/
│   └── server.ts
├── dist/
├── .env
├── package.json
├── package-lock.json
├── tsconfig.json
└── README.md
```

## 4. Prerequisites

- Node.js
- npm
- Git
- A Supabase project

## 5. Installation

Navigate to the backend directory:

```bash
cd backend
```

Install dependencies:

```bash
npm install
```

## 6. Environment Configuration

Create a `.env` file inside the backend directory.

Add the following variables:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_PUBLISHABLE_KEY=your_supabase_publishable_key
PORT=3000
```

Use the actual values from the team's Supabase project.

**Security:** Never commit `.env` files or expose the Supabase secret/service role key in the Flutter application or Git repository.

## 7. Running the Backend

### Development

```bash
npm run dev
```

### Production Build

```bash
npm run build
```

### Production Start

```bash
npm start
```

The production build generates JavaScript files in `dist/`.

## 8. API Server

Default local base URL:

```text
http://localhost:3000
```

Health endpoint:

```http
GET /
```

Expected response:

```json
{
  "message": "AI-Powered Mobile DevOps Command Center API is running!"
}
```

## 9. Authentication

The backend uses Supabase Authentication.

Protected API requests require the user's Supabase access token:

```http
Authorization: Bearer YOUR_SUPABASE_ACCESS_TOKEN
```

The backend validates the token and creates a user-scoped Supabase client.

### Get Authenticated User

```http
GET /api/me
```

Requires a valid access token.

## 10. API Route Groups

| Route | Purpose |
|---|---|
| `/api/me` | Authenticated user details |
| `/api/incidents` | Incident management |
| `/api/dashboard` | Dashboard statistics |
| `/api/investigations` | Incident investigation records |
| `/api/approvals` | Remediation approval management |
| `/api/audit-logs` | Audit log access |
| `/api/playbook-runs` | Playbook execution requests and decisions |
| `/api/postmortems` | Incident postmortems |
| `/api/remediation-executions` | Remediation execution records |
| `/api/admin` | User administration |
| `/api/admin/playbooks` | Playbook administration |
| `/api/admin/integrations` | Integration administration |

Protected routes require authentication. Individual endpoints enforce authorization and database Row Level Security policies.

Refer to the team's API documentation for endpoint methods, request bodies, response formats, and examples.

## 11. TypeScript Validation

Check for TypeScript errors:

```bash
npx tsc --noEmit
```

## 12. Development Notes

- Do not commit `.env` or other secrets.
- Never expose the Supabase service role key to the mobile application.
- Follow the team's Git feature-branch and pull-request workflow.
- Coordinate database schema and API contract changes with the relevant team members.