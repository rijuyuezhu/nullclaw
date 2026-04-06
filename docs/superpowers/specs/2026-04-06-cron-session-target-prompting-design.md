# Cron Session Target Prompting Design

## Goal

Improve the model's understanding that scheduled agent jobs should default to `session_target="isolated"`, while preserving the intentional `main` routing added in PR #666 for tasks that truly need main-session post-processing.

## Background

PR #666 correctly wired `CronJob.session_target` so agent jobs can choose between two delivery modes:

- `isolated`: default, raw output delivered directly
- `main`: route the result through the main agent session for personality, memory, and skill-based reinterpretation

The behavior is correct, but the current prompt surface over-emphasizes `main` as the richer option. In practice, that nudges the model to pick `main` for ordinary reminders, even when the user expects a direct delivery reminder.

This is especially visible for one-shot reminder prompts like "5 minutes later remind me to take a walk", where `main` causes the result to enter the main session instead of being delivered directly to the originating chat.

## Non-Goals

- No runtime behavior changes
- No schema or validation changes
- No new guardrails or enforcement logic
- No changes to the underlying design of PR #666

## Design Principles

1. Keep `main` available as an explicit advanced mode.
2. Teach `isolated` as the normal default for reminders and notifications.
3. Explain `main` in terms of intent, not superiority.
4. Reinforce the same rule in more than one prompt surface so the model learns a stable heuristic.

## Proposed Changes

### 1. Reframe the `schedule` tool description

Update `src/tools/schedule.zig` so the tool description no longer recommends `main` by default.

Current messaging emphasizes:

- set `session_target` to `main`
- route results through the main agent

New messaging should emphasize:

- scheduled agent jobs default to `isolated`
- use `isolated` for reminders, alarms, and direct channel delivery
- use `main` only when the scheduled result should be reinterpreted by the main assistant before replying

This keeps the feature discoverable without framing `main` as the preferred path.

### 2. Rewrite the `session_target` parameter description symmetrically

Update the JSON schema text for `session_target` in `src/tools/schedule.zig`.

The current wording makes `main` sound like the higher-value option because it promises "contextualised responses" while `isolated` is described as merely delivering raw output.

Replace that with a balanced comparison:

- `isolated` (default): direct delivery, best for reminders and notifications
- `main`: opt-in post-processing through the main session, best for tasks that intentionally need personality, memory, or tool-assisted reinterpretation

The point is not to hide `main`, but to make its cost and purpose explicit.

### 3. Strengthen the global scheduled-task guidance

Update the scheduled-task section in `src/agent/prompt.zig` so the model sees a general rule outside the tool schema.

Add short guidance such as:

- For one-shot reminders and simple scheduled notifications, prefer `isolated`.
- If the user expects the reminder itself to be delivered back to the current chat, keep it `isolated`.
- Use `main` only when the scheduled task is intentionally feeding information into the main assistant for rewriting, interpretation, or follow-up reasoning.

This makes the routing rule part of the agent's broader behavioral guidance rather than only a tool-specific footnote.

### 4. Add contrasting examples

Add one positive example for each mode near the scheduled-task guidance.

Recommended examples:

- Reminder example: `5 minutes later remind me to take a walk` -> `session_target="isolated"`
- Main-agent example: `Every morning, gather git status and have the main assistant summarize what needs attention` -> `session_target="main"`

Examples are likely to be more sticky for the model than prose alone.

## Why This Should Work

The model currently sees prompt content from two relevant places:

- global agent instructions in `src/agent/prompt.zig`
- raw tool descriptions and parameter schemas, which are injected directly into the prompt

The current tool schema wording makes `main` sound more attractive. By changing both the tool-level and global wording, we teach one clear heuristic in two places:

- reminder-like tasks -> `isolated`
- interpretation/rewrite workflows -> `main`

That preserves the PR #666 design while reducing accidental misuse.

## Risks

1. If the wording becomes too strong, the model may underuse `main` even when it is appropriate.
2. If examples are too narrow, the model may overfit to the exact wording rather than the intent.

## Mitigations

1. Keep `main` documented as a valid opt-in mode.
2. Describe task categories, not just literal strings.
3. Use paired examples so both modes remain visible.

## Testing Strategy

This change is prompt-only, so the main verification should be targeted regression coverage around prompt generation and tool metadata.

Add or update tests that verify:

1. `schedule` tool description mentions `isolated` as the default for reminders/notifications.
2. `session_target` schema text describes `isolated` as the default direct-delivery mode.
3. The scheduled-task guidance in `agent/prompt.zig` includes explicit preference for `isolated` for reminders.
4. The prompt still documents `main` as an available opt-in mode for tasks that require main-session reinterpretation.

## Acceptance Criteria

1. The model-facing prompt no longer frames `main` as the default or implicitly better mode.
2. Reminder and notification use cases are explicitly associated with `isolated`.
3. `main` remains documented for intentional post-processing workflows.
4. Existing `session_target` behavior remains unchanged.
