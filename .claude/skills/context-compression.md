# Context Compression

This skill provides techniques for compressing content to preserve context budget.

## When to Compress

Compress when you encounter:

- API responses longer than 20 lines
- JSON payloads with more than 5 relevant fields
- Test output exceeding 50 lines
- Conversation history beyond 10 exchanges
- Multiple similar error messages
- Repeated code patterns

## Compression Techniques

### JSON API Response Compression

**Large API Response**

Before (full JSON):
```json
{
  "id": "usr_abc123",
  "email": "user@example.com",
  "name": "Jane Doe",
  "created_at": "2025-01-15T10:23:45Z",
  "updated_at": "2025-06-20T14:30:00Z",
  "status": "active",
  "role": "admin",
  "team_id": "team_xyz789",
  "last_login": "2025-06-20T08:15:00Z",
  "preferences": {
    "theme": "dark",
    "notifications": true,
    "timezone": "America/New_York"
  },
  "permissions": ["read", "write", "admin"],
  "subscription": {
    "plan": "enterprise",
    "expires_at": "2026-01-15T00:00:00Z",
    "seats": 50,
    "usage": 32
  }
}
```

After (compressed):
```
User usr_abc123: Jane Doe (admin, active) - enterprise plan, 32/50 seats
```

**Paginated List Response**

Before (20+ items with full objects):
```json
{
  "data": [
    {"id": "item_001", "name": "Widget A", "status": "active", ...},
    {"id": "item_002", "name": "Widget B", "status": "active", ...},
    ...
  ],
  "meta": {"total": 156, "page": 1, "per_page": 20}
}
```

After:
```
Items: 156 total, page 1/8 - all active, names: Widget A..Widget T
```

**Error Response**

Before:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {"field": "email", "message": "Invalid email format", "value": "not-an-email"},
      {"field": "age", "message": "Must be a positive integer", "value": -5},
      {"field": "role", "message": "Must be one of: admin, user, viewer", "value": "superadmin"}
    ],
    "request_id": "req_def456"
  }
}
```

After:
```
Validation error (req_def456): 3 field errors - email (format), age (positive), role (enum)
```

### Test Output Compression

**Jest Results**

Before (100+ lines):
```
PASS __tests__/unit/handlers/create-user.test.js
  create-user handler
    ✓ creates user with valid input (15 ms)
    ✓ validates required fields (3 ms)
    ✓ handles duplicate email (2 ms)
    ✓ returns proper error format (4 ms)

PASS __tests__/unit/handlers/update-user.test.js
  ...
```

After:
```
Tests: 12 passed (users: 4, auth: 4, billing: 4) - all green
```

**Failed Test**

Before:
```
FAIL __tests__/unit/handlers/create-user.test.js
  ● create-user › should return error for missing email

    expect(received).toEqual(expected)

    Expected: {"success": false, "error": "Missing required field: email"}
    Received: {"success": false, "error": "Missing field"}
```

After:
```
FAIL: create-user "missing email" test
Expected error: "Missing required field: email"
Got: "Missing field"
```

### Error Log Compression

**Repeated Errors**

Before (multiple entries):
```
[ERROR] 2025-01-15 10:23:45 Request failed
  URL: POST /api/users
  Response: 502 Bad Gateway

[ERROR] 2025-01-15 10:23:52 Request failed
  URL: POST /api/users
  Response: 502 Bad Gateway

[ERROR] 2025-01-15 10:24:01 Request failed
  ...
```

After:
```
Error: POST /api/users returning 502 - 5 occurrences in 2 min
```

**Mixed Error Types**

Before (20+ log entries):
```
[ERROR] 10:23:45 DB connection timeout (pool exhausted)
[WARN]  10:23:46 Retry attempt 1/3 for query_abc
[ERROR] 10:23:47 DB connection timeout (pool exhausted)
[ERROR] 10:23:48 Redis cache miss for session_xyz
[WARN]  10:23:49 Retry attempt 2/3 for query_abc
...
```

After:
```
Errors (10:23-10:25): DB timeout x3 (pool exhausted), Redis cache miss x2, query retries exhausting
```

### Code Pattern Compression

When referencing code that has already been discussed or is a well-known pattern:

**Before** (repeating full implementation):
```javascript
const express = require('express');
const router = express.Router();

router.post('/users', async (req, res) => {
  try {
    const { email, name, role } = req.body;
    if (!email) return res.status(400).json({ error: 'Missing email' });
    const user = await db.users.create({ email, name, role });
    return res.status(201).json(user);
  } catch (err) {
    return res.status(500).json({ error: 'Internal error' });
  }
});
```

**After** (reference by name):
```
Uses standard CRUD handler pattern (validate → create → respond) from create-user.js
```

### Conversation History Compression

**Long Development Session**

Before (15 exchanges):
```
User: Create a user registration API
Assistant: [200 lines of implementation]
User: Add email validation
Assistant: [100 lines of changes]
User: Tests are failing
Assistant: [debugging discussion]
User: Now it passes
...
```

After:
```
Session summary:
- Created user registration API with validation
- Files: create-user.js, validate-input.js + tests
- Tests: All passing
- Current: Ready for review
```

## Compression Patterns

| Content Type | Compression Ratio | Key Elements to Preserve |
|--------------|-------------------|-------------------------|
| API response | 5:1 | IDs, status, key fields relevant to task |
| JSON payload | 4:1 | Structure shape, field count, key values |
| Test output (pass) | 10:1 | Count by category, all green |
| Test output (fail) | 3:1 | Test name, expected vs received |
| Error logs | 5:1 | Error type, endpoint, count, timeframe |
| Conversation | 8:1 | Decisions made, files changed, current state |
| Code patterns | 4:1 | Pattern name, key variation from standard |

## Format-Specific Compression

Different output formats have different compression strategies:

| Format | Strategy | Example |
|--------|----------|---------|
| JSON objects | Extract key fields only | `User: id, name, status` |
| XML/HTML | Summarize as element flow | `Form → Input(email) → Submit → Response` |
| Log files | Group by type + count | `Error X: 5 occurrences in 2 min` |
| CLI output | Keep status + counts | `Deploy: success, 3 functions updated` |
| Stack traces | Keep top frame + root cause | `TypeError at handler.js:42 - null.property` |

## When NOT to Compress

Keep full context when:

- Actively debugging (need exact error messages)
- Writing new code (need exact patterns to follow)
- First encounter with a new API (need full documentation)
- Code review (need exact line numbers)
- Security audit (need full credential patterns)
