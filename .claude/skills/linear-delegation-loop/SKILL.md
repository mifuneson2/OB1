---
name: linear-delegation-loop
description: |
  Use when running work between agents and people through Linear as a shared task
  layer (the "Open Orchestrator" loop). Fires when: writing a self-contained
  "agent instructions" ticket for another person's agent to execute; executing
  tickets assigned to you that carry the trigger; reporting results back inside
  the ticket; answering another agent's blocker in-thread; or cleaning up finished
  issues after a run. Trigger phrases: "make an agent ticket", "have the agent pick
  this up", "watch Linear for my tasks", "clean up the Linear issues".
author: Jonathan Edwards
version: 1.0.0
---

# Linear Delegation Loop (Open Orchestrator)

## Problem

Work needs to move between multiple agents and multiple people, across different
AI clients (Claude, Codex, others), without files and context bouncing around in
chat. The fix: **Linear is the shared substrate. The ticket is the contract.** Any
agent that can read and write Linear can pick up, execute, and hand off work — no
matter whose agent it is or which model runs it.

## Trigger Conditions

- Asked to delegate work to someone else's agent, or to your own on a schedule.
- A Linear issue is **assigned to you** AND its **title contains "agent instructions"**
  (the automation trigger) — optionally tagged with the `agent-instructions` label.
- Asked to clean up / close out Linear issues after an agent finished executing.
- Another agent left a blocking question in a ticket you own.

## The contract (conventions — keep these stable)

- **Routing:** an executable ticket has `agent instructions` in the **title** and is
  **assigned to the operator** whose automation should run it. Also apply the
  `agent-instructions` label for a clean filterable view.
- **Self-contained:** the ticket body is a runbook a human could follow — inputs,
  steps, acceptance criteria, and a report-back format. No outside context required.
- **Assets are pointers, never payloads.** Hand off **links** (Google Drive, Content
  Master Pro, a repo path, or a Linear attachment/comment), not raw files. The
  executing agent fetches by reference.
- **Sub-issues** break a parent runbook into ordered, single-purpose steps.

## Process

### A. Planner (writing a ticket)
1. Title: `[agent instructions] <short outcome>`; assign to the target operator; add
   the `agent-instructions` label; set the project.
2. Body: context → inputs (as links) → steps → acceptance criteria → report-back
   format. Spell out the two execution paths if relevant (Codex native vs Claude +
   image/tool skill).
3. Split into sub-issues when there's a natural sequence (build → execute → report).

### B. Executor (running a ticket assigned to you)
1. Query Linear for issues assigned to you with `agent instructions` in the title that
   are not Done/Canceled. Process **oldest-updated first**.
2. Read the full description **and sub-issues**. Fetch any linked assets.
3. Do the work exactly as specified. If anything is ambiguous, **do not guess** —
   leave a comment with the question and move to the next issue.
4. Report back **in the ticket**: post results (attachments or links) + one summary
   comment (what you did, paths/models used, picks/notes), then move to the review
   state.
5. **Dedupe:** skip issues you already completed (check for your own prior comment or
   a review/Done state) so you never double-process. End the run when none remain.

### C. Cleanup (after work is verified done)
1. Confirm the deliverable actually landed (attached/linked in the right issue).
2. Move finished issues to **Done**; leave a one-line closing summary on each.
3. Make statuses honest (no work left in `In Progress` that isn't being worked).
4. Do **not** reopen, duplicate, or re-run completed issues.

## Cross-agent etiquette

- If another agent asks a blocker question in a ticket, answer it **in-thread** and,
  if you can, unblock it — that hand-off *is* the loop.
- Keep one clean summary per issue rather than a noisy play-by-play. The ticket diff
  is the record.

## Guard rails (safety)

- **Human-in-the-loop for outward-facing actions.** Never publish, send, or post
  externally without explicit human approval. The human stays the director.
- Honor claim discipline carried in the ticket (e.g. unverified cost figures).
- Stay inside the assigned issue's scope; large refactors or cross-project changes
  get a question, not an action.

## Output

A Linear issue that moved through the loop with: the work done, results filed on the
issue, an honest status, and a clean closing summary — ready for human review or the
next agent in the chain.

## Notes for other clients (Codex / Claude / Cursor)

- **Codex:** stand this up as a recurring automation that queries Linear every 15–60
  min, runs section B on each match, and applies section C when a ticket says clean up.
- **Claude / Cursor:** same contract; invoke this skill when a request matches the
  trigger conditions. Use your Linear MCP tools to read/write issues and comments.
- The trigger string and label are the only coupling — keep them identical across
  every agent so the substrate stays interoperable.
