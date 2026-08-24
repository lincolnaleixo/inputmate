#!/bin/zsh

set -euo pipefail

keychain_path="${INPUTMATE_BUILD_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
state_path="${INPUTMATE_KEYCHAIN_STATE_FILE:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/inputmate-keychain-state}"

[[ -f "$keychain_path" ]] || {
  print -u2 -- "unlock-build-keychain.sh: keychain not found: $keychain_path"
  exit 1
}
[[ -n "${MAC_BUILD_KEYCHAIN_PASSWORD:-}" ]] || {
  print -u2 -- "unlock-build-keychain.sh: MAC_BUILD_KEYCHAIN_PASSWORD is required"
  exit 1
}
export INPUTMATE_BUILD_KEYCHAIN="$keychain_path"
if [[ ! -f "$state_path" ]]; then
  if /usr/bin/security show-keychain-info "$keychain_path" >/dev/null 2>&1; then
    print -r -- unlocked > "$state_path"
  else
    print -r -- locked > "$state_path"
  fi
fi

# security prompts for the password when -p is omitted. Reading the secret
# through expect keeps it out of the process argument list and command logs.
/usr/bin/expect <<'EOF'
log_user 0
set timeout 30
set password $::env(MAC_BUILD_KEYCHAIN_PASSWORD)
set keychain [file normalize $::env(INPUTMATE_BUILD_KEYCHAIN)]
spawn security unlock-keychain $keychain
expect {
  -re "(?i)password.*:" {
    send -- "$password\r"
    exp_continue
  }
  eof {}
}
set result [wait]
exit [lindex $result 3]
EOF

unset MAC_BUILD_KEYCHAIN_PASSWORD
print -- "unlock-build-keychain.sh: keychain unlocked"
