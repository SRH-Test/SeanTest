# Builds inline review comments for SAST findings at or above --arg min_severity that sit on lines
# visible in the PR diff. Each body carries a hidden marker so reruns don't post duplicates.
include "common";

. as $r
| ($r.meta.policies | map({key: .name, value: .enforcement}) | from_entries) as $mode
| [$r.sast[]
   | select((.severity | sev_rank) <= ($min_severity | sev_rank))
   | . as $f
   | select($f.line != null and any(($r.diff[$f.file] // [])[]; . == $f.line))
   | guidance_for(.cwes) as $guide
   | {
       path: .file,
       line: .line,
       side: "RIGHT",
       body: ([
         "<!-- wiz-finding:\(.rule_id):\(.file):\(.line) -->",
         "\(.severity | sev_icon) **\(.severity | sev_label) · Code security (SAST)**",
         "",
         "**\(.title)**",
         "",
         ([(.cwes | map(cwe_link) | join(", ")),
           "Rule `\(.rule_id)`",
           (if (.policies | length) > 0
            then "Policy: \(.policies | map("\(.) (\(($mode[.] // "AUDIT") | ascii_downcase))") | join(", "))"
            else empty end)]
          | map(select(length > 0)) | join(" · ")),
         "",
         (if $guide then "**How to fix:** \($guide[1])" else empty end),
         (if .remediation then "\n<details>\n<summary>Remediation details from Wiz</summary>\n\n\(.remediation)\n\n</details>" else empty end),
         (if ($guide == null and .remediation == null) then "See this finding in Wiz for remediation guidance." else empty end)
       ] | join("\n"))
     }
  ]
