#!/bin/bash
# Temporary local routine for datasets from servicodados.ibge.gov.br.
#
# GitHub runners cannot connect to that host, so the weekly workflow fails for
# these datasets. This routine refreshes them from this Mac and uploads them to
# the cache-latest release. Remove it once the runners can reach IBGE or the
# datasets move to another source.
#
#   ./data-raw/pipeline/run_ibge_local.sh install    # set up, schedule weekly
#   ./data-raw/pipeline/run_ibge_local.sh uninstall  # unschedule, delete files
#   ~/.local/share/realestatebr-ibge/run.sh          # run once now
#
# Logs: ~/.local/share/realestatebr-ibge/logs/

set -euo pipefail

home_dir="$HOME/.local/share/realestatebr-ibge"
label="com.ekio.realestatebr-ibge"
plist="$HOME/Library/LaunchAgents/$label.plist"
repo_url="https://github.com/viniciusoike/realestatebr.git"

install_routine() {
  mkdir -p "$home_dir/logs" "$home_dir/lib"
  cp "$0" "$home_dir/run.sh"
  chmod +x "$home_dir/run.sh"
  [ -d "$home_dir/repo" ] || git clone -q --branch main "$repo_url" "$home_dir/repo"

  # launchd runs a missed job when the Mac wakes up.
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$home_dir/run.sh</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string></dict>
</dict>
</plist>
PLIST
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist"
  echo "Scheduled for Mondays at 09:00. Run now with: $home_dir/run.sh"
}

uninstall_routine() {
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  rm -f "$plist"
  rm -rf "$home_dir"
  echo "Removed the routine."
}

notify_on_failure() {
  local status=$?
  if [ "$status" -ne 0 ]; then
    osascript -e "display notification \"Check $log_file\" with title \"IBGE data refresh failed\"" || true
  fi
}

run_routine() {
  log_file="$home_dir/logs/$(date +%F).log"
  trap notify_on_failure EXIT
  exec >> "$log_file" 2>&1
  echo "=== $(date)"

  cd "$home_dir/repo"
  git fetch -q origin main
  git checkout -q --detach origin/main

  export R_LIBS="$home_dir/lib"
  export GITHUB_TOKEN
  GITHUB_TOKEN="$(gh auth token)"
  R CMD INSTALL --no-docs --library="$home_dir/lib" .

  local pipeline_status=0
  Rscript -e '
    library(targets)
    options(timeout = 600)
    pattern <- "^(sinapi|pim_pf_construction|paic|pnad_housing)_"
    tar_make(
      names = tidyselect::matches(pattern),
      callr_function = NULL
    )
    meta <- tar_meta(fields = "error")
    errored <- meta[grepl(pattern, meta$name) & !is.na(meta$error), ]
    if (nrow(errored) > 0) {
      cli::cli_abort(c("Failed: {.val {errored$name}}", errored$error))
    }
  ' || pipeline_status=$?

  # Upload whatever succeeded. The marker moves only after every upload works,
  # so a failed upload is retried next week.
  local marker="$home_dir/last-upload"
  [ -f "$marker" ] || touch -t 200001010000 "$marker"
  local next_marker="$home_dir/.next-upload"
  touch "$next_marker"
  find data-raw/cache_output -name '*.rds' -newer "$marker" \
    \( -name 'sinapi.rds' -o -name 'pim_pf_construction.rds' \
       -o -name 'paic_*.rds' -o -name 'pnad_housing_*.rds' \) \
    -print0 |
    while IFS= read -r -d '' file; do
      gh release upload cache-latest "$file" --clobber --repo viniciusoike/realestatebr
      echo "Uploaded $file"
    done
  mv "$next_marker" "$marker"

  return "$pipeline_status"
}

case "${1:-run}" in
  install) install_routine ;;
  uninstall) uninstall_routine ;;
  run) run_routine ;;
  *) echo "Usage: $0 [install|uninstall|run]" >&2; exit 2 ;;
esac
