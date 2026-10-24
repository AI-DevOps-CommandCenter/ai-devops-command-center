# AI Investigation Prompts

This directory stores prompts used by the AI-powered incident investigation workflows.

## Planned Prompts

* **Root Cause Analysis:** Analyze incident details and suggest possible causes.
* **Log Analysis:** Identify errors and unusual patterns in application logs.
* **Remediation Suggestions:** Recommend possible recovery actions.
* **Incident Summary:** Generate a concise incident summary for the operations team.

## Guidelines

* Base recommendations on the available incident evidence.
* Clearly distinguish confirmed facts from possible causes.
* Never allow AI-generated recommendations to execute remediation automatically without the required approval.
* Do not include passwords, API keys, access tokens, or other secrets in prompts.
