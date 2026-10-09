# Wiz Security Scan for Pull Requests

This GitHub Actions workflow scans every pull request with the Wiz CLI and reports the results on the pull request itself. Developers see code issues, vulnerable dependencies and exposed secrets before the change is merged, without leaving GitHub.

It covers:

- **Code security (SAST):** issues such as SQL injection, cross-site scripting and command injection in your source code
- **Dependency vulnerabilities:** known CVEs in the open-source packages your project uses
- **Secrets:** passwords, keys and tokens committed to the repository

Pass/fail decisions come from your Wiz policies. You manage severity thresholds and enforcement in Wiz, not in the workflow.

---

## What you'll see on a pull request

### 1. A summary comment

The workflow posts one comment on the pull request and updates it on every new push, so the conversation doesn't fill up with repeated reports.

The comment includes:

- **Result:** whether the scan passed, raised policy warnings, or failed a blocking policy
- **Severity overview:** a count of Critical, High, Medium, Low and Info findings for code, dependencies and secrets
- **Code findings:** each issue with its severity, a link to the exact file and line, its CWE reference and the Wiz policy it matched
- **Dependency findings:** each vulnerable package with its installed version, the version that fixes it and a link to the advisory. Findings with a known public exploit are marked 💥
- **Secrets:** each exposed secret with a link to where it was found
- **Scan details:** the policies evaluated and whether they audit or block, the Wiz CLI version and the scan time
- **A link to the full report in Wiz**

Sections with High or Critical findings are expanded; the rest are collapsed to keep the comment short.

### 2. Inline comments on the affected lines

High and Critical code findings also get a review comment directly on the line that caused them. Each one includes:

- what the issue is and its CWE reference
- the Wiz rule and policy that flagged it
- a short **How to fix** note
- Wiz's detailed remediation guidance, with examples, in an expandable section

Each finding is commented on once. Pushing more commits doesn't create duplicates.

### 3. A check on the pull request

The **Wiz scan** check appears with the other checks on the pull request:

- ✅ **Passes** when no blocking Wiz policy is violated. Findings from audit-mode policies are still reported but don't fail the check.
- ❌ **Fails** when a finding violates a Wiz policy set to **Block**, or when the scan itself can't run.

To prevent merging when the check fails, make it a required status check (see [Optional: block merging on failures](#optional-block-merging-on-failures)).

### 4. GitHub code scanning (Security tab)

Results are also uploaded to GitHub code scanning, so findings appear under the repository's **Security → Code scanning** page and as annotations on the pull request's **Files changed** tab.

> Code scanning is free for public repositories. Private repositories need GitHub Advanced Security (GitHub Code Security). Without it, this step is skipped and everything else still works.

### 5. A summary on the workflow run

The same report is shown on the workflow run's summary page under the **Actions** tab.

---

## Setup

Setup takes about 10 minutes and needs admin access to the repository.

### Before you start

You need:

1. **A Wiz service account** with permission to run CLI scans. Ask your Wiz administrator for its **Client ID** and **Client Secret**.
2. **A Wiz SAST policy for CI/CD scans.** In Wiz, go to **Policies → CI/CD Scan Policies** and check that a SAST policy exists and applies to the **Build** lifecycle. Note its exact name. Without a SAST policy, code findings are not returned.

### Step 1: Add the files to your repository

Copy these into your repository, keeping the same folder structure:

```
.github/
├── workflows/
│   └── main.yml          ← the workflow (you can rename it, e.g. wiz-scan.yml)
└── wiz/
    ├── report.sh         ← builds the report from the scan results
    ├── normalize.jq
    ├── render.jq
    ├── review.jq
    ├── common.jq
    └── README.md         ← this file
```

Commit them to your default branch (usually `main` or `master`).

### Step 2: Add your Wiz credentials as secrets

1. In your repository, go to **Settings → Secrets and variables → Actions**.
2. Select **New repository secret** and add:

   | Name | Value |
   |---|---|
   | `WIZ_CLIENT_ID` | your Wiz service account Client ID |
   | `WIZ_CLIENT_SECRET` | your Wiz service account Client Secret |

Secrets are encrypted and never shown in logs.

> If you use the workflow in several repositories, add the secrets once at the organization level instead: **Organization settings → Secrets and variables → Actions**.

### Step 3: Set your Wiz policies

Open `.github/workflows/main.yml` and find this line near the top:

```yaml
WIZ_POLICIES: Default vulnerabilities policy,Default secrets policy,Default software license policy,SRH-Test
```

Replace it with the names of the Wiz policies you want to evaluate, separated by commas. Names must match Wiz exactly, including capitalization. Make sure the list includes your SAST policy from **Before you start**.

This is the only setting in the workflow.

### Step 4: Test it

Open a pull request with any change. Within a few minutes:

- the **Wiz scan** check appears on the pull request
- the summary comment is posted
- inline comments appear on any High or Critical code findings

If something doesn't appear, see [Troubleshooting](#troubleshooting).

### Optional: block merging on failures

To stop pull requests from merging when a blocking Wiz policy is violated:

1. Go to **Settings → Rules → Rulesets** (or **Settings → Branches** for classic branch protection).
2. Create a rule for your default branch and enable **Require status checks to pass**.
3. Add **Wiz scan** as a required check.

The check fails only on policies set to **Block** in Wiz, so you control what blocks a merge from Wiz without editing the workflow.

---

## How it works

1. A pull request is opened, or new commits are pushed to it.
2. The workflow installs the latest Wiz CLI and scans the repository with your policies.
3. The results are filtered to what the pull request changed:
   - code findings and secrets are shown only for **files changed in the pull request**
   - dependency findings are shown for the packages your project uses
4. The summary comment is posted or updated, inline comments are added, and the results are uploaded to code scanning.
5. The check passes or fails according to your Wiz policies.

Each scan also appears in Wiz under **CI/CD scans**, tagged with the repository, pull request number and commit, so your security team can find it.

If you push again while a scan is running, the older scan is cancelled and the newest commit is scanned.

---

## Changing what passes or fails

You manage everything in Wiz:

| To… | Do this in Wiz |
|---|---|
| Fail the check on certain findings | Set the policy's enforcement to **Block** |
| Report findings without failing the check | Set the policy's enforcement to **Audit** |
| Change which severities a policy flags | Change the policy's severity threshold |
| Add or remove a type of scanning | Add or remove the policy name in `WIZ_POLICIES` in the workflow |

The **Scan details** section of the summary comment shows which policies were evaluated and whether each one audits or blocks.

---

## Troubleshooting

| What you see | Likely cause | What to do |
|---|---|---|
| The comment says **"The scan did not complete"** | The Wiz credentials are missing or wrong, or a policy name in `WIZ_POLICIES` doesn't exist | Check both secrets in Step 2, then open the workflow run from the **Checks** tab and look at the **Run Wiz scan** step for the error |
| No **Code security (SAST)** section | No SAST policy is being evaluated | Add your SAST policy's exact name to `WIZ_POLICIES`, and check in Wiz that the policy applies to the **Build** lifecycle |
| `Policy not found` in the **Run Wiz scan** step | A name in `WIZ_POLICIES` doesn't match Wiz, or the policy doesn't apply to the Build lifecycle | Copy the name exactly from Wiz and check its lifecycle setting |
| The check fails, but the comment shows only warnings | A policy set to **Block** was violated | See **Scan details** in the comment for which policies block |
| No comment on pull requests from forks | GitHub doesn't give workflows from forks access to secrets or write permissions | This is a GitHub security restriction; scans run for branches in the same repository |
| No inline comments | Only High and Critical code findings on lines changed in the pull request get inline comments | Lower-severity findings, and findings on unchanged lines, are listed in the summary comment |
| The **Upload results to GitHub code scanning** step shows an error | Code scanning isn't enabled for the repository | Enable it under **Settings → Code security**, or ignore it; the rest of the workflow is unaffected |
| `Resource not accessible by integration` | Your organization restricts what workflows can write | Ask an organization owner to allow `pull-requests: write` for Actions under **Organization settings → Actions → General** |

---

## Permissions

The workflow uses the repository's built-in `GITHUB_TOKEN` with only these permissions:

| Permission | Used for |
|---|---|
| `contents: read` | checking out the code to scan |
| `pull-requests: write` | posting the summary comment and inline comments |
| `security-events: write` | uploading results to GitHub code scanning |
| `actions: read` | required by the code scanning upload on private repositories |

The Wiz CLI is downloaded from Wiz's official download site (`downloads.wiz.io`) on each run and stored outside your repository, so it is never part of the scan.
