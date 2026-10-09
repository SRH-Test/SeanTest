# Shared helpers for the Wiz PR report.

def sev_rank: {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "INFORMATIONAL": 4}[.] // 5;
def norm_sev: (. // "UNKNOWN") | ascii_upcase | if . == "INFO" then "INFORMATIONAL" else . end;
def sev_icon: {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "LOW": "🔵", "INFORMATIONAL": "⚪"}[.] // "⚫";
def sev_label: {"CRITICAL": "Critical", "HIGH": "High", "MEDIUM": "Medium", "LOW": "Low", "INFORMATIONAL": "Info"}[.] // "Unknown";
def worst_severity: map(.severity) | min_by(sev_rank);

def rel_path: sub("^(file://)?(\\./|/)+"; "");
def url_path: split("/") | map(@uri) | join("/");
def version_key: [scan("[0-9]+") | tonumber];
def plural($n; $word):
  "\($n) \(if $n == 1 then $word elif ($word | endswith("y")) then ($word | rtrimstr("y")) + "ies" else $word + "s" end)";

# Make a value safe inside a Markdown table cell
def cell: tostring | gsub("\\|"; "\\|") | gsub("[\r\n]+"; " ");

def cwe_link: "[\(.)](https://cwe.mitre.org/data/definitions/\(sub("^CWE-"; "")).html)";

# Short name and fix for common weaknesses, used to group findings into recommended fixes
# and as remediation text when the Wiz output carries none.
def cwe_guidance: {
  "CWE-79":  ["Cross-site scripting", "Encode user input before writing it into HTML (use a templating engine with auto-escaping) and set a Content-Security-Policy."],
  "CWE-80":  ["Cross-site scripting", "Encode user input before writing it into HTML (use a templating engine with auto-escaping) and set a Content-Security-Policy."],
  "CWE-116": ["Cross-site scripting", "Encode user input before writing it into HTML (use a templating engine with auto-escaping) and set a Content-Security-Policy."],
  "CWE-89":  ["SQL injection", "Use parameterized queries (placeholders with bound values) instead of building SQL strings from user input."],
  "CWE-78":  ["Command injection", "Avoid invoking a shell: call the program directly with an argument array (e.g. `execFile`/`spawn`) and validate input against an allowlist."],
  "CWE-77":  ["Command injection", "Avoid invoking a shell: call the program directly with an argument array (e.g. `execFile`/`spawn`) and validate input against an allowlist."],
  "CWE-94":  ["Code injection", "Never evaluate user input as code. Replace `eval`/`new Function` with `JSON.parse` or an explicit allowlist of operations."],
  "CWE-95":  ["Code injection", "Never evaluate user input as code. Replace `eval`/`new Function` with `JSON.parse` or an explicit allowlist of operations."],
  "CWE-22":  ["Path traversal", "Resolve the requested path and verify it stays inside the intended base directory; reject absolute paths and `..` segments."],
  "CWE-23":  ["Path traversal", "Resolve the requested path and verify it stays inside the intended base directory; reject absolute paths and `..` segments."],
  "CWE-918": ["Server-side request forgery", "Validate outbound URLs against an allowlist of schemes and hosts, and block internal and link-local address ranges."],
  "CWE-601": ["Open redirect", "Redirect only to relative paths or to an allowlist of trusted hosts."],
  "CWE-327": ["Weak cryptography", "Hash passwords with a slow, salted algorithm such as bcrypt, scrypt or Argon2; don't use MD5 or SHA-1."],
  "CWE-328": ["Weak cryptography", "Hash passwords with a slow, salted algorithm such as bcrypt, scrypt or Argon2; don't use MD5 or SHA-1."],
  "CWE-916": ["Weak cryptography", "Hash passwords with a slow, salted algorithm such as bcrypt, scrypt or Argon2; don't use MD5 or SHA-1."],
  "CWE-352": ["Cross-site request forgery", "Protect state-changing routes with CSRF tokens and `SameSite` cookies."],
  "CWE-770": ["Missing rate limiting", "Add rate limiting to public endpoints (e.g. `express-rate-limit`)."],
  "CWE-400": ["Missing rate limiting", "Add rate limiting to public endpoints (e.g. `express-rate-limit`)."],
  "CWE-117": ["Log injection", "Strip CR/LF from user input before logging it, or use a structured logger."],
  "CWE-319": ["Cleartext transmission", "Serve and call services over HTTPS/TLS instead of plain HTTP."],
  "CWE-200": ["Information exposure", "Don't return or publish sensitive information such as stack traces, configuration or system details."],
  "CWE-798": ["Hard-coded credentials", "Move credentials to a secret manager or environment variables and rotate the exposed values."],
  "CWE-476": ["Null dereference", "Check for null or undefined values before dereferencing them."],
  "CWE-502": ["Insecure deserialization", "Don't deserialize untrusted data with formats that can instantiate objects; use JSON with schema validation."],
  "CWE-611": ["XML external entities", "Disable DTDs and external entity resolution in the XML parser."]
};

# [name, fix] for the first CWE in the list that has guidance, else null
def guidance_for($cwes): first($cwes[] | cwe_guidance[.] // empty) // null;
