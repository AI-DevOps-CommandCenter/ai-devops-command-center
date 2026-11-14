# Automation – Decision Proposals for the Team

**Status:** proposals only (12 Nov 2026), prepared on the n8n side for the owner of `database/DATABASE_DECISION_REGISTER.md`. Nothing here changes the register, the contract or the security configuration. Once the team decides, the register owner records the outcome and the n8n side follows it.

---

## D-N8N-1: how n8n Code nodes get `MACHINE_SIGNING_SECRET`

**Facts (checked in the code)**
- The HMAC signing and verification run in n8n Code nodes and read the secret with `$env.MACHINE_SIGNING_SECRET`:
  - `automation/src/lib/hmac.js` (`signedBackendRequest`), included in the signing nodes of 05, 06 and 07;
  - `automation/src/nodes/06-remediation/verify-request.js` (incoming BD-5 webhook).
- The workflows also read non-secret configuration with `$env` (URLs, timeouts, modes).
- `$env` only works in a Code node when `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`.

**Inconsistency to resolve**

| Where | Says |
|---|---|
| `database/API_AND_INTEGRATION_CONTRACTS.md` B.3 (A5 rules) | `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` |
| `automation/docker-compose.yml` | `"false"`, with a comment pointing to this decision |
| `docs/automation-implementation-guide.md`, `automation/README.md`, `docs/automation-integration-requirements.md` §6 | `false` is needed; decision open |

With `true`, the Code nodes cannot read the secret, so no signed backend call and no BD-5 webhook verification can work (the exact failure mode under `true` has not been tested).

**Options**

| | Option | Effect | Cost / risk |
|---|---|---|---|
| A | Keep `false` and record an exception to A5 | Works today | Any Code node, and anyone who can edit workflows, can read every variable passed to the container. Mitigations already in place: only the listed variables are passed (`docker-compose.yml`), API keys live in n8n Credentials, n8n published on `127.0.0.1` (N-5). Still needed: a single trusted owner account / limited editors. |
| B | Set `true` and move the secret out of `$env` (e.g. HMAC in a node that takes the key from n8n Credentials, or a small signing service next to n8n) | Matches A5 | Needs a spike: n8n Community Edition has no `$secrets`/external secrets for Code nodes, so the signing logic and its tests would have to be rebuilt. Not possible before the 30 Nov deadline without risk. |

**Proposal:** adopt **A** for local development and the project demo, recorded as an explicit, time-limited exception to A5 with the mitigations above. Revisit B before any shared or hosted deployment. Then align the contract wording (B.3) with the decision.

**Decision needed from:** the decision-register owner (database team) together with the team (A5 owner).

---

## D-N8N-6: atomic replay protection for the remediation webhook (known issue KI-1)

**Problem:** workflow 06 keeps accepted nonces in workflow static data. n8n saves static data only when an execution ends and the last execution to end overwrites the others, so concurrent requests are not detected by n8n and a nonce can be lost. The exact same signed request can then pass n8n's replay check again within the 5-minute window. Details and test evidence: `docs/automation-integration-requirements.md` §6a, `npm run test:n8n:replay` (S5 fails on purpose).

**Today's protection:** the run state in the database (`start_playbook_run` locks the run and moves it from `approved` to `running` once). Observed with a **mock** backend only: no run started twice. The real database lock was not exercised.

**Proposal:** replay protection for backend → n8n requests must use an **atomic, shared** nonce store. The preferred direction is to reuse the existing database store (`consume_automation_nonce`, migration `000400`, already used by the backend for n8n → backend calls), reached from n8n through a signed machine endpoint, so the nonce is consumed atomically before 06 continues. Any other atomic mechanism the backend/database team prefers is acceptable.

**Until then:** keep the static-data check as a first filter, keep relying on the database run state, and keep the strict S5 test.

**Decision needed from:** backend + database team (they own the nonce store and the machine endpoints); the n8n side will adapt workflow 06 once the mechanism exists.
