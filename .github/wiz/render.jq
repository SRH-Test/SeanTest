# Renders the normalized report as the PR summary comment (Markdown).
# Args: --arg repo, --arg sha, --arg server, --arg run_url, --arg inline_min, --argjson max_rows
include "common";

def blob($file; $line): "\($server)/\($repo)/blob/\($sha)/\($file | url_path)" + (if $line then "#L\($line)" else "" end);
def location: "[`\(.file)\(if .line then ":\(.line)" else "" end)`](\(blob(.file; .line)))";
def cwes_cell: if (.cwes | length) == 0 then "—" else (.cwes | map(cwe_link) | join(", ")) end;
def policy_cell($mode):
  if (.policies | length) == 0 then "—"
  else .policies | map("\(.) (\(($mode[.] // "AUDIT") | ascii_downcase))") | join(", ") end;
def severity_cell: "\(.severity | sev_icon) \(.severity | sev_label)";
def advisory:
  if .url then "[\(.id)](\(.url))"
  elif (.id | test("^CVE-")) then "[\(.id)](https://nvd.nist.gov/vuln/detail/\(.id))"
  elif (.id | test("^GHSA-")) then "[\(.id)](https://github.com/advisories/\(.id))"
  else .id end;

def count_row($label; $items):
  ($items | group_by(.severity) | map({key: .[0].severity, value: length}) | from_entries) as $c
  | "| \($label) | \(["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFORMATIONAL"] | map($c[.] // 0 | if . == 0 then "·" else tostring end) | join(" | ")) | **\($items | length)** |";

# Cap long tables; the full list is always in the Wiz report
def capped($rows):
  $rows[:$max_rows] + (if ($rows | length) > $max_rows
                       then ["", "_…and \(($rows | length) - $max_rows) more. See the full report in Wiz._"] else [] end);

# Collapsible section, expanded when it contains anything High or worse
def section($title; $items; $header; $rows):
  if ($items | length) == 0 then [] else
    ["<details\(if any($items[]; (.severity | sev_rank) <= 1) then " open" else "" end)>",
     "<summary><b>\($title) (\($items | length))</b></summary>", "", $header[0], $header[1]]
    + capped($rows) + ["", "</details>", ""]
  end;

def verdict_line:
  {"PASSED_BY_POLICY": "✅ **Passed**: no policy violations",
   "WARN_BY_POLICY": "⚠️ **Policy warnings**: findings match audit-mode policies",
   "FAILED_BY_POLICY": "❌ **Failed**: findings violate blocking policies"}[.meta.verdict // ""]
  // "ℹ️ **Scan complete**";

. as $r
| ($r.meta.policies | map({key: .name, value: .enforcement}) | from_entries) as $mode
| ($r.sast + $r.deps + $r.secrets) as $all
| [
    "<!-- ID: WIZ_SECURITY_SCAN_COMMENT_MARKER -->",
    "## 🛡️ Wiz Security Scan",
    "",
    "\($r | verdict_line) · **\(plural($all | length; "finding"))** · \(plural($r.meta.changed_files; "changed file")) · commit [`\($sha[:7])`](\($server)/\($repo)/commit/\($sha))",
    ""
  ]
  + (if ($all | length) == 0 then ["No security findings in the files changed by this pull request. 🎉", ""] else
    [
      "| Category | 🔴 Critical | 🟠 High | 🟡 Medium | 🔵 Low | ⚪ Info | Total |",
      "|---|:-:|:-:|:-:|:-:|:-:|:-:|",
      count_row("🧬 Code (SAST)"; $r.sast),
      count_row("📦 Dependencies"; $r.deps),
      count_row("🔑 Secrets"; $r.secrets),
      ""
    ]
    + (if any($r.sast[]; (.severity | sev_rank) <= ($inline_min | sev_rank))
       then ["_\($inline_min | sev_label)-severity and worse code findings also have inline review comments with remediation on the affected lines._", ""] else [] end)
    + ["### 📋 Findings", ""]
    + section("🧬 Code security (SAST)"; $r.sast;
        ["| Severity | Finding | Location | CWE | Policy |", "|---|---|---|---|---|"];
        [$r.sast[] | "| \(severity_cell) | \(.title | cell) | \(location) | \(cwes_cell) | \(policy_cell($mode)) |"])
    + section("📦 Dependency vulnerabilities"; $r.deps;
        ["| Severity | Package | Vulnerability | Installed | Fixed in | Policy |", "|---|---|---|---|---|---|"];
        [$r.deps[] | "| \(severity_cell) | `\(.package | cell)` | \(advisory)\(if .exploit then " 💥" else "" end) | \(.version | cell) | \(.fixed // "—" | cell) | \(policy_cell($mode)) |"])
    + section("🔑 Exposed secrets"; $r.secrets;
        ["| Severity | Secret | Location | Policy |", "|---|---|---|---|"];
        [$r.secrets[] | "| \(severity_cell) | \(.title | cell) | \(location) | \(policy_cell($mode)) |"])
    + (if any($r.deps[]; .exploit) then ["<sub>💥 A public exploit is available.</sub>", ""] else [] end)
  end)
  + [
    "<details>",
    "<summary>Scan details</summary>",
    "",
    "| | |",
    "|---|---|",
    "| Verdict | `\($r.meta.verdict // "n/a")` |",
    "| Policies | \(if ($r.meta.policies | length) == 0 then "—" else ($r.meta.policies | map("\(.name) (\(.enforcement | ascii_downcase))") | join(", ")) end) |",
    "| Enforcement | \([$r.meta.policies[] | select(.enforcement == "BLOCK") | .name] | if length == 0 then "Audit only: this check never fails on findings" else "Fails this check on violations of \(join(", "))" end) |",
    "| Wiz CLI | \($r.meta.cli_version // "n/a") |",
    "| Scanned | \($r.meta.scanned_at // "n/a" | . as $t | try (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 | strftime("%Y-%m-%d %H:%M UTC")) catch $t) |",
    "| Commit | `\($sha)` |",
    "",
    "</details>",
    "",
    ([(if $r.meta.report_url then "[**View the full report in Wiz →**](\($r.meta.report_url))" else empty end),
      (if $run_url != "" then "[Workflow run](\($run_url))" else empty end)] | join(" · "))
  ]
| join("\n")
