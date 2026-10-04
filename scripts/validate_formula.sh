#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Copy the working files so Docker also tests uncommitted formula changes.
tap_dir="$(brew --repository)/Library/Taps/local/homebrew-tap-validation"
if [[ -e "$tap_dir" ]]; then
  echo "Validation tap already exists: $tap_dir" >&2
  exit 1
fi
mkdir -p "$tap_dir/Formula"
trap 'rm -rf "$tap_dir"' EXIT
cp "$repo_root"/Formula/*.rb "$tap_dir/Formula/"

brew style "$tap_dir"/Formula/*.rb
for formula in naiveproxy xray; do
  name="local/tap-validation/$formula"
  brew audit --strict --formula "$name"
  # This runs the formula's install method; the inputs are upstream binaries.
  brew install --formula --build-from-source "$name"
  brew test "$name"
done

config="$(brew --prefix)/etc/xray/config.json"
xray run -test -config "$config"
# Reinstall must preserve user-managed configuration under etc.
printf '\n' >> "$config"
before="$(shasum -a 256 "$config")"
brew reinstall --formula --build-from-source local/tap-validation/xray
[[ "$(shasum -a 256 "$config")" == "$before" ]]
brew test local/tap-validation/xray
