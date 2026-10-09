# Renders the normalized report as the PR summary comment (Markdown).
# Args: --arg repo, --arg sha, --arg server, --arg run_url, --arg fail_on, --arg inline_min, --argjson max_rows
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

def code_fixes:
  [.sast[] | . + {group: (guidance_for(.cwes)[0] // "Other findings")}]
  | group_by(.group)
  | map({name: .[0].group, guide: guidance_for([.[].cwes[]]), cwes: ([.[].cwes[]] | unique),
         count: length, worst: worst_severity})
  | sort_by((.worst | sev_rank), -.count)
  | map("- \(.worst | sev_icon) **\(.name)**\(if (.cwes | length) > 0 then " (\(.cwes | map(cwe_link) | join(", ")))" else "" end): "
        + "\(plural(.count; "finding")). \(if .guide then .guide[1] else "See each finding in Wiz for remediation guidance." end)");

def dependency_fixes:
  .upgrades | map(
    if .transitive then
      "- \(.worst | sev_icon) **`\(.package)` \(.version)**: \(plural(.count; "vulnerability")) fixed only through a parent dependency. Upgrade the package that pulls it in, or pin a patched version with an override."
    elif .target == null then
      "- \(.worst | sev_icon) **`\(.package)` \(.version)**: \(plural(.count; "vulnerability")) with no fixed version yet. Consider replacing the package or mitigating the affected code paths."
    else
      "- \(.worst | sev_icon) **Upgrade `\(.package)` \(.version) → \(.target)** in `\(.path)`: fixes "
      + (if .unfixed == 0 then (if .count == 1 then "1 vulnerability" else "all \(plural(.count; "vulnerability"))" end)
         else "\(.count - .unfixed) of \(plural(.count; "vulnerability"))" end)
      + " (\(.by_severity | to_entries | sort_by(.key | sev_rank) | map("\(.value) \(.key | sev_label)") | join(", ")))."
    end);

. as $r
| ($r.meta.policies | map({key: .name, value: .enforcement}) | from_entries) as $mode
| ($r.sast + $r.deps + $r.secrets) as $all
| ($r | code_fixes) as $code_fixes
| ($r | dependency_fixes) as $dep_fixes
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
    + (if ($code_fixes + $dep_fixes | length) == 0 then [] else
        ["### 🔧 Recommended fixes", ""]
        + (if ($code_fixes | length) > 0 then ["**Code**", ""] + $code_fixes + [""] else [] end)
        + (if ($dep_fixes | length) > 0 then ["**Dependencies**", ""] + $dep_fixes + [""] else [] end)
        + (if any($r.sast[]; (.severity | sev_rank) <= ($inline_min | sev_rank))
           then ["_\($inline_min | sev_label)-severity and worse code findings also have inline review comments on the affected lines._", ""] else [] end)
      end)
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
    "| Gate | \(if $fail_on == "NONE" then "Report only" else "Fails on \($fail_on | sev_label) or worse" end) |",
    "| Wiz CLI | \($r.meta.cli_version // "n/a") |",
    "| Scanned | \($r.meta.scanned_at // "n/a") |",
    "| Commit | `\($sha)` |",
    "",
    "</details>",
    "",
    ([(if $r.meta.report_url then "[**View the full report in Wiz →**](\($r.meta.report_url))" else empty end),
      (if $run_url != "" then "[Workflow run](\($run_url))" else empty end)] | join(" · "))
  ]
| join("\n")
