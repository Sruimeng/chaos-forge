---
id: doc-standard
type: guide
description: The 4 Laws of Documentation
---

# Documentation Standard

> **Mission:** High signal. Low noise. Code > English.

## Law 1: Frontmatter Mandatory

Every document MUST begin with YAML frontmatter.

**Required Fields:**
```yaml
---
id: unique-identifier        # Kebab-case, no spaces
type: guide|reference|architecture|strategy
description: Single-line summary (max 80 chars)
---
```

**Optional Fields:**
```yaml
related_ids: [auth-system, user-model]  # Knowledge graph links
status: draft|active|deprecated
updated: 2026-02-09
```

**Enforcement:**
- Missing frontmatter = invalid document
- Parser: `id` field enables knowledge graph indexing
- Reason: Librarian agents depend on structured metadata

## Law 2: Type-First Design

Data structures define reality. Prose is commentary.

**Priority Order:**
1. **Code Blocks** (TypeScript interfaces, SQL schemas, Rust structs)
2. **Tables** (for state machines, configuration matrices)
3. **Bullet Points** (for rules, constraints)
4. **Prose** (only for "why", never "what")

**Example (GOOD):**
```typescript
interface AuthToken {
  sub: string;      // User ID
  exp: number;      // Unix timestamp
  roles: string[];  // RBAC permissions
}
```

**Example (BAD):**
```markdown
The authentication token contains a subject identifier which represents
the user, an expiration timestamp, and a list of role-based access control
permissions that determine what the user can do.
```

**Rule:** If you can express it in code, DO NOT use English.

## Law 3: Pseudocode Logic

Complex logic = Compact pseudocode, not paragraphs.

**Template:**
```
FUNCTION process_request(req):
  IF req.auth IS NULL:
    RETURN 401

  user = db.find(req.auth.sub)
  IF user.banned:
    RETURN 403

  RETURN handle(req, user)
```

**Constraints:**
- Max 20 lines per block
- Use guards (early returns)
- Align with actual code structure
- No natural language explanations inside pseudocode

**When to Use:**
- Algorithms with >3 conditional branches
- State machine transitions
- Multi-step workflows

## Law 4: No Meta-Narrative

Delete all "tour guide" language.

**Banned Phrases:**
- ❌ "In this section, we will..."
- ❌ "Let's explore how..."
- ❌ "This document describes..."
- ❌ "Here is an example of..."
- ❌ "As you can see..."
- ❌ "Introduction", "Conclusion"

**Allowed Patterns:**
- ✅ Direct headers: `## Error Handling`
- ✅ Imperative rules: `MUST validate input.`
- ✅ Blockquote summaries: `> Token expires after 24h.`

**Rationale:**
- Readers are engineers, not tourists
- Iceberg Principle: Show interface, hide justification
- Hemingway Standard: "Omit needless words"

**Self-Check:**
```
IF line.contains("this section"):
  DELETE line
IF line.startsWith("Introduction"):
  DELETE section
```

---

## Document Types

| Type | Purpose | Structure |
|------|---------|-----------|
| `reference` | API contracts, data models | Types + Rules |
| `architecture` | System design, boundaries | Diagrams + Constraints |
| `guide` | Standards, protocols | Laws + Examples |
| `strategy` | Implementation plans | Pseudocode + Decisions |

## Validation Protocol

Before saving any document:

```
CHECK frontmatter.id EXISTS
CHECK frontmatter.type IN [guide, reference, architecture, strategy]
CHECK content CONTAINS code_blocks OR tables
CHECK content NOT CONTAINS ["Introduction", "in this section", "let's"]
```

**Violation = Rejection.**

---

## Meta

**Authority:** Surveyor (The Cartographer)
**Scope:** All `/llmdoc` content
**Enforcement:** Critic agent, Librarian agent
**Style Basis:** Hemingway Principle (Iceberg, High Signal)
