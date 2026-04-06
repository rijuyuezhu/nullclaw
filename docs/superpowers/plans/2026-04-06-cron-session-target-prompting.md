# Cron Session Target Prompting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach the model that scheduled reminders and notifications should default to `session_target="isolated"` while preserving `main` as an explicit opt-in mode for post-processing workflows.

**Architecture:** This is a prompt-only change. Update the model-facing guidance in the `schedule` tool metadata and the global scheduled-task section of the system prompt, then add regression tests that assert the new wording is present and still documents `main` as an available opt-in mode.

**Tech Stack:** Zig 0.15.2, std.testing, existing prompt/tool metadata generation in `src/agent/prompt.zig` and `src/tools/schedule.zig`

---

### Task 1: Reframe `schedule` Tool Metadata

**Files:**
- Modify: `src/tools/schedule.zig:23-25`
- Test: `src/tools/schedule.zig:490-576`

- [ ] **Step 1: Write the failing metadata test**

Add these assertions near the existing schema tests in `src/tools/schedule.zig`:

```zig
test "schedule tool description prefers isolated for reminders" {
    var st = ScheduleTool{};
    const t = st.tool();

    try std.testing.expect(std.mem.indexOf(u8, t.description(), "default to isolated") != null);
    try std.testing.expect(std.mem.indexOf(u8, t.description(), "reminders") != null);
    try std.testing.expect(std.mem.indexOf(u8, t.description(), "main") != null);
}

test "schedule schema describes isolated as direct delivery default" {
    var st = ScheduleTool{};
    const t = st.tool();
    const schema = t.parametersJson();

    try std.testing.expect(std.mem.indexOf(u8, schema, "isolated") != null);
    try std.testing.expect(std.mem.indexOf(u8, schema, "direct delivery") != null);
    try std.testing.expect(std.mem.indexOf(u8, schema, "reminders and notifications") != null);
    try std.testing.expect(std.mem.indexOf(u8, schema, "opt-in") != null);
}
```

- [ ] **Step 2: Run the schedule tests to verify failure**

Run:

```bash
zig test src/tools/schedule.zig
```

Expected: FAIL because the current tool description still says `Set session_target to 'main'...` and does not mention `default to isolated` or `opt-in` wording.

- [ ] **Step 3: Update the tool description and schema text**

Replace the current metadata strings in `src/tools/schedule.zig` with wording along these lines:

```zig
pub const tool_description = "Manage scheduled tasks. Actions: create/add/once/list/get/cancel/remove/pause/resume. Use 'command' for shell jobs or 'prompt' (with optional 'model') for agent jobs. Optional delivery params: channel, account_id, chat_id. Scheduled agent jobs default to isolated for reminders, notifications, and direct channel delivery. Use session_target='main' only when the result should be routed through the main agent for post-processing.";

pub const tool_params =
    \\{"type":"object","properties":{"action":{"type":"string","enum":["create","add","once","list","get","cancel","remove","pause","resume"],"description":"Action to perform"},"expression":{"type":"string","description":"Cron expression for recurring tasks"},"delay":{"type":"string","description":"Delay for one-shot tasks (e.g. '30m', '2h')"},"command":{"type":"string","description":"Shell command to execute"},"prompt":{"type":"string","description":"Agent prompt for an agent job"},"model":{"type":"string","description":"Optional model override for agent jobs"},"id":{"type":"string","description":"Task ID"},"channel":{"type":"string","description":"Delivery channel for notifications (e.g. telegram, signal, matrix)"},"account_id":{"type":"string","description":"Optional channel account ID for multi-account routing"},"chat_id":{"type":"string","description":"Chat ID for delivery notification"},"session_target":{"type":"string","enum":["isolated","main"],"description":"Routing mode for agent jobs: 'isolated' (default) uses direct delivery and is best for reminders and notifications; 'main' is an opt-in mode that routes through the main agent session for personality, memory, or tool-assisted post-processing"}},"required":["action"]}
;
```

- [ ] **Step 4: Re-run the schedule tests to verify pass**

Run:

```bash
zig test src/tools/schedule.zig
```

Expected: PASS, including the new metadata assertions.

- [ ] **Step 5: Commit the metadata change**

Run:

```bash
git add src/tools/schedule.zig
git commit -m "docs(prompt): prefer isolated for scheduled reminders"
```

Expected: commit succeeds with the prompt-only metadata update.

### Task 2: Strengthen Global Scheduled-Task Guidance

**Files:**
- Modify: `src/agent/prompt.zig:402-407`
- Test: `src/agent/prompt.zig:1207-1223`

- [ ] **Step 1: Write the failing system-prompt test**

Add a focused regression test near the existing `buildSystemPrompt` tests in `src/agent/prompt.zig`:

```zig
test "buildSystemPrompt prefers isolated for reminders and keeps main opt-in" {
    const allocator = std.testing.allocator;
    const prompt = try buildSystemPrompt(allocator, .{
        .workspace_dir = "/tmp/nonexistent",
        .model_name = "test-model",
        .tools = &.{},
    });
    defer allocator.free(prompt);

    try std.testing.expect(std.mem.indexOf(u8, prompt, "prefer `isolated`") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "one-shot reminders") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "current chat") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "Use `main` only") != null);
}
```

- [ ] **Step 2: Run the prompt tests to verify failure**

Run:

```bash
zig test src/agent/prompt.zig
```

Expected: FAIL because the current scheduled-task section only mentions double quotes and Telegram auto-delivery, not the new `isolated`/`main` guidance.

- [ ] **Step 3: Update the scheduled-task guidance text**

Expand the global scheduled-task section in `src/agent/prompt.zig` so it includes the routing heuristic and contrasting examples. Keep the existing shell-command reminder guidance, but append text along these lines:

```zig
try w.writeAll("- For one-shot reminders and simple scheduled notifications, prefer `isolated`\n");
try w.writeAll("- If the user expects the reminder itself to be delivered back to the current chat, keep it `isolated`\n");
try w.writeAll("- Use `main` only when the scheduled task is intentionally feeding information into the main assistant for rewriting, interpretation, or follow-up reasoning\n\n");
try w.writeAll("Examples:\n");
try w.writeAll("- `5 minutes later remind me to take a walk` -> `session_target=\"isolated\"`\n");
try w.writeAll("- `Every morning, gather git status and have the main assistant summarize it` -> `session_target=\"main\"`\n\n");
```

Keep the wording concise so the prompt remains readable.

- [ ] **Step 4: Re-run the prompt tests to verify pass**

Run:

```bash
zig test src/agent/prompt.zig
```

Expected: PASS, including the new scheduled-task guidance test.

- [ ] **Step 5: Commit the prompt guidance change**

Run:

```bash
git add src/agent/prompt.zig
git commit -m "docs(prompt): clarify cron isolated vs main routing"
```

Expected: commit succeeds with the global prompt guidance update.

### Task 3: Run Final Verification

**Files:**
- Verify: `src/tools/schedule.zig`
- Verify: `src/agent/prompt.zig`

- [ ] **Step 1: Run targeted verification for both changed files**

Run:

```bash
zig test src/tools/schedule.zig && zig test src/agent/prompt.zig
```

Expected: PASS for both targeted test suites.

- [ ] **Step 2: Run repository formatting and full test verification**

Run:

```bash
zig fmt --check src/ && zig build test --summary all
```

Expected: formatting passes; full suite passes with 0 failures and 0 leaks.

- [ ] **Step 3: Inspect final diff before handoff**

Run:

```bash
git diff -- src/tools/schedule.zig src/agent/prompt.zig docs/superpowers/specs/2026-04-06-cron-session-target-prompting-design.md docs/superpowers/plans/2026-04-06-cron-session-target-prompting.md
```

Expected: diff only shows prompt/documentation wording and test additions, with no runtime logic changes.

- [ ] **Step 4: Commit final verification state**

Run:

```bash
git add src/tools/schedule.zig src/agent/prompt.zig docs/superpowers/specs/2026-04-06-cron-session-target-prompting-design.md docs/superpowers/plans/2026-04-06-cron-session-target-prompting.md
git commit -m "docs(prompt): teach cron reminders to prefer isolated"
```

Expected: final commit captures the prompt updates, tests, and planning docs.
