# Normalizes wizcli JSON + SARIF output and the PR's changed files into one report document.
# Usage: jq -n -L .github/wiz --slurpfile wiz result.json --slurpfile sarif result.sarif \
#           --slurpfile files pr_files.json -f normalize.jq
include "common";

($wiz[0] // {}) as $w
| ($sarif[0] // {}) as $s
| ($files[0] // []) as $pr_files

# Right-side line numbers visible in each changed file's diff; inline comments can only go on these
| ([$pr_files[] | select(.status != "removed") | {
    key: .filename,
    value: ((.patch // "") | split("\n") | reduce .[] as $l ({n: 0, lines: []};
      if ($l | startswith("@@")) then .n = ($l | capture("\\+(?<s>[0-9]+)").s | tonumber)
      elif ($l | startswith("-")) or ($l | startswith("\\")) then .
      elif ($l | startswith("+")) then .lines += [.n] | .n += 1
      else .lines += [.n] | .n += 1 end) | .lines)
  }] | from_entries) as $diff

# SARIF carries every finding type; SAST rules are the ones that aren't CVEs, advisories or secrets
| ([$s.runs[]?.tool.driver.rules[]?
    | select(.id | test("^(CVE-|GHSA-|SECRET-)"; "i") | not)
    | select((.properties.tags // []) | map(ascii_downcase) | any(. == "secret" or . == "vulnerability" or . == "license") | not)
    | .id] | unique) as $sast_ids
| ($sast_ids | map({key: ., value: true}) | from_entries) as $is_sast

# CWEs, failed policies and remediation text only exist in the JSON's nested result.sast. Collect them
# per rule from any object that references exactly one SAST rule ID, so the nesting doesn't matter.
| ([($w.result.sast // empty) | .. | objects
    | . as $o | tostring as $str
    | [$sast_ids[] | select(. as $id | $str | contains("\"" + $id + "\""))] as $matched
    | select($matched | length == 1)
    | {id: $matched[0],
       cwes: [$str | scan("(?i)cwe[-_ ]?([0-9]+)") | "CWE-" + .[0]],
       policies: [$o | .. | objects | (.failedPolicyMatches? // empty) | .[]? | (.policy.name? // empty)],
       remediation: ([$o | .. | objects | to_entries[]
                      | select((.key | test("remediation|recommendation|mitigation"; "i")) and (.value | type == "string") and (.value | length > 20))
                      | .value] | .[0])}
  ] | group_by(.id)
    | map({key: .[0].id, value: {cwes: ([.[].cwes[]] | unique), policies: ([.[].policies[]] | unique),
                                 remediation: ([.[].remediation | values] | .[0])}})
    | from_entries) as $rule_info

| ([$s.runs[]? as $run
    | ($run.tool.driver.rules // []) as $rules
    | ($run.results // [])[] as $res
    | select($is_sast[$res.ruleId // ""])
    | ($rules | map(select(.id == $res.ruleId)) | .[0] // {}) as $rule
    | ($res.locations[0].physicalLocation // {}) as $loc
    | ($rule_info[$res.ruleId] // {}) as $info
    | (($rule.properties."security-severity" // null) | if . == null then null else tonumber end) as $score
    | {
        rule_id: $res.ruleId,
        title: ($rule.shortDescription.text // $rule.name // $res.message.text // $res.ruleId),
        severity: (((($rule.properties.tags // []) | map(norm_sev) | map(select(sev_rank < 5)) | .[0])
                    // (if $score == null then null
                        elif $score >= 9 then "CRITICAL" elif $score >= 7 then "HIGH"
                        elif $score >= 4 then "MEDIUM" elif $score > 0 then "LOW" else "INFORMATIONAL" end))
                   // "UNKNOWN"),
        file: (($loc.artifactLocation.uri // "") | rel_path),
        line: ($loc.region.startLine // null),
        cwes: ((([$rule.properties, $res.properties] | tostring | [scan("(?i)cwe[-_ ]?([0-9]+)") | "CWE-" + .[0]])
                + ($info.cwes // [])) | unique),
        policies: ($info.policies // []),
        remediation: ($rule.help.markdown // $rule.help.text // $info.remediation // null)
      }
    | select($diff[.file] != null)
  ] | unique_by([.rule_id, .file, .line]) | sort_by((.severity | sev_rank), .file, .line)) as $sast

| ([(($w.result.libraries // []), ($w.result.osPackages // []))[] as $p
    | ($p.vulnerabilities // [])[]
    | {package: $p.name, version: ($p.version // ""), path: (($p.path // "") | rel_path),
       id: (.name // .id), severity: (.severity | norm_sev), fixed: (.fixedVersion // null),
       url: (.source // null), exploit: ((.hasExploit // .hasPublicExploit // false) == true),
       policies: [(.failedPolicyMatches // [])[] | (.policy.name? // empty)]}
  ] | sort_by((.severity | sev_rank), .package, .id)) as $deps

# One upgrade recommendation per package: the lowest version that fixes all its fixable CVEs.
# A "fix" older than the installed version means the fix lives in a parent dependency.
| ([$deps | group_by([.package, .version, .path])[] as $g
    | ([$g[].fixed | values | split(",") | .[0] | gsub("^\\s+|\\s+$"; "") | select(length > 0)]
       | max_by(version_key)) as $target
    | {package: $g[0].package, version: $g[0].version, path: $g[0].path, target: $target,
       count: ($g | length), unfixed: ([$g[] | select(.fixed == null)] | length),
       worst: ($g | worst_severity),
       by_severity: ($g | group_by(.severity) | map({key: .[0].severity, value: length}) | from_entries),
       transitive: ($target != null and (($target | version_key) <= ($g[0].version | version_key)))}
  ] | sort_by((.worst | sev_rank), -.count)) as $upgrades

| ([($w.result.secrets // [])[]
    | {title: (.description // .ruleName // "Secret"), file: ((.path // .filename // "") | rel_path),
       line: ((.lineNumber // .line // null) | if . == null then null else (tonumber? // null) end),
       severity: (.severity | norm_sev),
       policies: [(.failedPolicyMatches // [])[] | (.policy.name? // empty)]}
    | select($diff[.file] != null)
  ] | sort_by((.severity | sev_rank), .file, .line)) as $secrets

| {
    meta: {
      verdict: ($w.status.verdict // null),
      report_url: ($w.reportUrl // null),
      cli_version: ($w.extraInfo.clientVersion // null),
      scanned_at: ($w.createdAt // null),
      policies: [($w.policies // [])[] | {name, enforcement: ([(.policyLifecycleEnforcements // [])[]
                   | select(.deploymentLifecycle == "CLI") | .enforcementMethod] | .[0] // "AUDIT")}],
      changed_files: ($diff | length)
    },
    diff: $diff, sast: $sast, deps: $deps, upgrades: $upgrades, secrets: $secrets
  }
