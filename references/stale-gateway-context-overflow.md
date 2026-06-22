# Stale Gateway: False Context Overflow Debugging

## Error Pattern

```
RuntimeError: Context length exceeded (4,959 tokens). Cannot compress further.
```

**Key indicator:** Token count is tiny (< 10,000). Real context overflows show 50K+ tokens.

## Root Cause

Gateway process started BEFORE a Hermes code update. Old in-memory modules lack new methods added in the update.

## Debugging Transcript (2026-06-02)

### Step 1: Check logs for the real error

```bash
grep "error_type=AttributeError" ~/.hermes/profiles/diary/logs/agent.log | tail -5
```

Output:
```
WARNING agent.conversation_loop: API call failed (attempt 1/3) error_type=AttributeError
  summary='ProviderProfile' object has no attribute 'get_max_tokens'
```

### Step 2: Check for stale module warnings

```bash
grep "stale in-memory module" ~/.hermes/profiles/diary/logs/agent.log | tail -3
```

Output:
```
WARNING agent.conversation_compression: compression lock subsystem unavailable
  (AttributeError: 'SessionDB' object has no attribute 'try_acquire_compression_lock')
  — proceeding without lock. This usually means a stale in-memory module after an
  update; restart the process to resync.
```

### Step 3: Compare gateway start time vs code update time

```bash
# Gateway start time
systemctl show hermes-gateway-diary.service --property=ActiveEnterTimestamp
# Output: ActiveEnterTimestamp=Fri 2026-05-29 11:19:12 CST

# Code update time
ls -la ~/.hermes/hermes-agent/providers/base.py
# Output: May 29 15:03
```

Gateway started at 11:19, code updated at 15:03 → stale modules confirmed.

### Step 4: Fix

```bash
hermes -p diary gateway restart
```

### Step 5: Verify by triggering the failed cron job

```bash
hermes -p diary cron run 86b172e7801e
# Check logs: should see successful API calls without AttributeError
```

## Timeline

| Date | Event |
|------|-------|
| 2026-05-29 11:19 | Diary gateway started |
| 2026-05-29 15:03 | `ProviderProfile.get_max_tokens` added to codebase |
| 2026-05-30 03:30 | First cron failure (stale module) |
| 2026-06-02 08:16 | Gateway restarted → cron job succeeds |

## Related Code

- `providers/base.py:132` — `get_max_tokens()` method
- `agent/transports/chat_completions.py:482` — where `profile.get_max_tokens(model)` is called
- `agent/chat_completion_helpers.py:700-728` — provider profile resolution and transport delegation
