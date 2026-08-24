# Configurable Action IPA Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users override the IPA app name and bundle identifier when manually running any IPA Action, with defaults of `EeveeSpotify` and `in.kelco.spotify.client`.

**Architecture:** Add two `workflow_dispatch` inputs to each IPA workflow, map them to workflow-level environment variables, and pass those quoted variables to `cyan`. Keep identity rewriting inside `cyan`, which already updates the main app, localized display names, and derived extension bundle identifiers.

**Tech Stack:** GitHub Actions YAML, Bash, `cyan` from `pyzule-rw`, PowerShell static assertions

## Global Constraints

- Modify only `.github/workflows/build-and-release-yourself.yml`, `.github/workflows/buildnopatch.yml`, and `.github/workflows/buildpatched.yml` during implementation.
- Default app name must be exactly `EeveeSpotify`.
- Default bundle identifier must be exactly `in.kelco.spotify.client`.
- Preserve custom values as data by passing GitHub inputs through environment variables, never direct shell interpolation.
- Do not change local build scripts, package metadata, or generated IPA filenames.

---

### Task 1: Add Configurable IPA Identity Inputs

**Files:**
- Modify: `.github/workflows/build-and-release-yourself.yml`
- Modify: `.github/workflows/buildnopatch.yml`
- Modify: `.github/workflows/buildpatched.yml`

**Interfaces:**
- Consumes: GitHub `workflow_dispatch` inputs `app_name` and `bundle_id`
- Produces: workflow environment variables `APP_NAME` and `BUNDLE_ID`, consumed by each `cyan` command through `-n` and `-b`

- [ ] **Step 1: Run the static assertion before implementation**

```powershell
$files = @(
  '.github/workflows/build-and-release-yourself.yml',
  '.github/workflows/buildnopatch.yml',
  '.github/workflows/buildpatched.yml'
)
foreach ($file in $files) {
  $text = Get-Content -Raw -LiteralPath $file
  if ($text -notmatch '(?ms)^      app_name:\r?\n.*?default: "EeveeSpotify"') { throw "$file missing app_name default" }
  if ($text -notmatch '(?ms)^      bundle_id:\r?\n.*?default: "in\.kelco\.spotify\.client"') { throw "$file missing bundle_id default" }
  if ($text -notmatch '(?m)^  APP_NAME: \$\{\{ inputs\.app_name \}\}$') { throw "$file missing APP_NAME mapping" }
  if ($text -notmatch '(?m)^  BUNDLE_ID: \$\{\{ inputs\.bundle_id \}\}$') { throw "$file missing BUNDLE_ID mapping" }
  if ($text -notmatch '-n "\$APP_NAME" -b "\$BUNDLE_ID"') { throw "$file missing quoted cyan identity options" }
}
```

Expected: FAIL on the first workflow with `missing app_name default` because the inputs do not exist yet.

- [ ] **Step 2: Add the inputs to every workflow**

Add these entries under each `workflow_dispatch.inputs` mapping:

```yaml
      app_name:
        description: "Installed app name"
        default: "EeveeSpotify"
        required: true
        type: string
      bundle_id:
        description: "Installed app bundle identifier"
        default: "in.kelco.spotify.client"
        required: true
        type: string
```

- [ ] **Step 3: Map inputs through the workflow environment**

Add these keys to the existing top-level `env` mapping in every workflow:

```yaml
  APP_NAME: ${{ inputs.app_name }}
  BUNDLE_ID: ${{ inputs.bundle_id }}
```

- [ ] **Step 4: Pass identity options to `cyan`**

Extend each existing `cyan` command without changing its other flags:

```bash
               -f "${INJECT[@]}" -n "$APP_NAME" -b "$BUNDLE_ID" -c 9 -m 15.0 -du
```

- [ ] **Step 5: Run the static assertion after implementation**

Run the PowerShell command from Step 1 again.

Expected: PASS with exit code `0` and no output.

- [ ] **Step 6: Verify scope and formatting**

```powershell
git diff --check
git diff --name-only
git diff -- .github/workflows/build-and-release-yourself.yml .github/workflows/buildnopatch.yml .github/workflows/buildpatched.yml
```

Expected: `git diff --check` exits `0`; implementation changes are limited to the three workflow files; the diff contains two inputs, two environment mappings, and two quoted `cyan` options per workflow.

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/build-and-release-yourself.yml .github/workflows/buildnopatch.yml .github/workflows/buildpatched.yml
git commit -m "ci: make IPA identity configurable"
```
