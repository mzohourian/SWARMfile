# Health Check

**Last Updated:** 2025-12-04

Run this checklist at session start AND end.

## 1. Documentation Check

| Check | How to Verify | Pass/Fail |
|-------|---------------|-----------|
| CLAUDE.md exists | File at `/home/user/SWARMfile/CLAUDE.md` | |
| PROJECT.md exists | File at `/home/user/SWARMfile/PROJECT.md` | |
| PROJECT.md is recent | "Last Updated" within 7 days | |
| Known issues listed | PROJECT.md has "Known Issues" section | |

## 2. Code Structure Check

| Check | How to Verify | Pass/Fail |
|-------|---------------|-----------|
| App folder exists | `/home/user/SWARMfile/OneBox/` directory present | |
| Core modules exist | `OneBox/Modules/CorePDF/`, `CoreImageKit/`, `JobEngine/` | |
| Main views exist | `OneBox/OneBox/Views/` has key files | |

## 3. Key Files Check

Verify these critical files exist and aren't empty:

| File | Purpose | Pass/Fail |
|------|---------|-----------|
| `OneBox/Modules/CorePDF/CorePDF.swift` | PDF processing | |
| `OneBox/Modules/CoreImageKit/CoreImageKit.swift` | Image processing | |
| `OneBox/Modules/JobEngine/JobEngine.swift` | Job queue | |
| `OneBox/OneBox/Views/ToolFlowView.swift` | Main tool flow | |
| `OneBox/OneBox/OneBoxApp.swift` | App entry point | |

## 4. Build Check (If Xcode Available)

| Check | Command | Pass/Fail |
|-------|---------|-----------|
| Project compiles | `xcodebuild -scheme OneBox build` | |
| No errors | Build completes without errors | |
| Warning count | Note number of warnings | |

**Note:** If Xcode is not available in the environment, mark as "N/A - No Xcode"

## 5. Known Issues Verification

Cross-check PROJECT.md known issues:

| Issue # | Still Present? | Got Worse? | Notes |
|---------|----------------|------------|-------|
| 1 | | | |
| 2 | | | |
| 3 | | | |

## 6. Session End Only: Change Audit

| Check | Answer |
|-------|--------|
| Files created this session | (list them) |
| Files modified this session | (list them) |
| Any placeholders or TODOs added? | YES/NO |
| Any new dependencies added? | YES/NO |
| Any features broken that worked before? | YES/NO |

---

## How to Report Results

**Format your report like this:**

```
HEALTH CHECK RESULTS - [DATE]

Documentation: PASS/FAIL
- [details if fail]

Code Structure: PASS/FAIL
- [details if fail]

Key Files: PASS/FAIL
- [details if fail]

Build: PASS/FAIL/N/A
- [details if fail]

Known Issues: [X] still present, [Y] resolved, [Z] new
- [details on changes]

Overall: HEALTHY / NEEDS ATTENTION / CRITICAL
```

---

## Red Flags (Stop and Report)

If any of these are true, stop and tell the user immediately:

- A file that existed before is now missing
- A feature that worked before is now broken
- Build errors that didn't exist before
- PROJECT.md shows issues you don't see in code
- Code shows issues not listed in PROJECT.md
