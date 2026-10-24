# Automation (n8n workflows and Groq prompts)

Owners: Tharindu, Vishwa

This folder holds the n8n workflows and the Groq prompts that investigate incidents.

**Safety principle:** The AI only recommends actions. It never executes commands.

## Folder guide

| Folder           | What it contains                                  |
| ---------------- | ------------------------------------------------- |
| `workflows/`     | Exported n8n workflow JSON files                  |
| `schemas/`       | JSON schema for validating AI output              |
| `prompts/`       | Groq system prompts                               |
| `github-gitlab/` | Notes and helpers for fetching deployment history |
| `docs/`          | Workflow diagrams and explanations                |

## Standard AI output format

Example:

```json
{
  "summary": "High error rate after deployment",
  "severity": "high",
  "evidence": ["Error rate increased after deployment"],
  "confidence": 0.85,
  "recommended_action": "rollback"
}
```

## Safety rule

The `recommended_action` field must contain exactly one of these values:

* `restart`
* `rollback`
* `scale`
* `circuit_breaker`

Any other value must be rejected by schema validation.
