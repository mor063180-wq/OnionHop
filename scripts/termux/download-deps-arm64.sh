#!/bin/bash
set -euo pipefail

# Prepare arm64 runtime dependencies for the OnionHop CLI.
# Run from the repository root on an arm64 Linux host.

REPO_ROOT="$(pwd)"
TOR_DIR="$REPO_ROOT/OnionHop/tor"
PT_DIR="$TOR_DIR/pluggable_transports"
ARTI_HOP_DIR="$REPO_ROOT/OnionHop/artihop"
SNOWFLAKE_DIR="$REPO_ROOT/OnionHop/snowflake"
TEMP_DIR="$REPO_ROOT/temp_deps_arm64"

# linux-aarch64 expert bundles were only published for alpha builds when this was written.
TOR_BUNDLE_VERSION="${TOR_BUNDLE_VERSION:-16.0a4}"
WEBTUNNEL_VERSION="${WEBTUNNEL_VERSION:-v0.0.3}"
BUILD_ARTIHOP="${BUILD_ARTIHOP:-false}"
SNOWFLAKE_PROXY_PACKAGE="gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2/proxy@latest"

if [ "$(uname -m)" != "aarch64" ]; then
  echo "This script must run on an arm64 host." >&2
  exit 1
fi

mkdir -p "$TOR_DIR" "$PT_DIR" "$ARTI_HOP_DIR" "$SNOWFLAKE_DIR" "$TEMP_DIR"

echo "== Tor expert bundle linux-aarch64 ($TOR_BUNDLE_VERSION)"
TOR_ARCHIVE="$TEMP_DIR/tor.tar.gz"
TOR_REL="$TOR_BUNDLE_VERSION/tor-expert-bundle-linux-aarch64-$TOR_BUNDLE_VERSION.tar.gz"
curl -fL "https://dist.torproject.org/torbrowser/$TOR_REL" -o "$TOR_ARCHIVE" || true
if ! gzip -t "$TOR_ARCHIVE" 2>/dev/null; then
  curl -fL "https://archive.torproject.org/tor-package-archive/torbrowser/$TOR_REL" -o "$TOR_ARCHIVE"
fi
tar -xzf "$TOR_ARCHIVE" -C "$TEMP_DIR"
echo "Bundle layout:"
(cd "$TEMP_DIR" && ls -R tor data 2>/dev/null | head -60)

cp "$TEMP_DIR/tor/tor" "$TOR_DIR/"
cp "$TEMP_DIR/data/geoip" "$TEMP_DIR/data/geoip6" "$TOR_DIR/"
cp "$TEMP_DIR/tor/"*.so* "$TOR_DIR/" 2>/dev/null || true
cp -r "$TEMP_DIR/tor/pluggable_transports/"* "$PT_DIR/"
if [ ! -f "$PT_DIR/lyrebird" ] && [ -f "$PT_DIR/obfs4proxy" ]; then
  mv "$PT_DIR/obfs4proxy" "$PT_DIR/lyrebird"
fi

echo "== webtunnel-client ($WEBTUNNEL_VERSION)"
curl -fL "https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel/-/archive/$WEBTUNNEL_VERSION/webtunnel-$WEBTUNNEL_VERSION.tar.gz" -o "$TEMP_DIR/webtunnel.tar.gz"
tar -xzf "$TEMP_DIR/webtunnel.tar.gz" -C "$TEMP_DIR"
WEBTUNNEL_SRC="$(find "$TEMP_DIR" -maxdepth 1 -type d -name 'webtunnel-*' | head -1)"
(cd "$WEBTUNNEL_SRC" && CGO_ENABLED=0 go build -ldflags "-s -w" -o "$PT_DIR/webtunnel-client" ./main/client)

echo "== dnstt-client"
git clone https://www.bamsoftware.com/git/dnstt.git "$TEMP_DIR/dnstt"
(cd "$TEMP_DIR/dnstt/dnstt-client" && CGO_ENABLED=0 go build -ldflags "-s -w" -o "$PT_DIR/dnstt-client" .)

echo "== Snowflake volunteer proxy"
mkdir -p "$TEMP_DIR/gobin"
CGO_ENABLED=0 GOBIN="$TEMP_DIR/gobin" go install "$SNOWFLAKE_PROXY_PACKAGE"
cp "$TEMP_DIR/gobin/proxy" "$SNOWFLAKE_DIR/snowflake-proxy"

if [ "$BUILD_ARTIHOP" = "true" ]; then
  echo "== ArtiHop"
  git clone --depth 1 https://github.com/center2055/ArtiHop.git "$TEMP_DIR/ArtiHop"
  (cd "$TEMP_DIR/ArtiHop" && cargo build --release)
  cp "$TEMP_DIR/ArtiHop/target/release/artihop" "$ARTI_HOP_DIR/"
fi

if [ -f "$PT_DIR/pt_config.json" ]; then
  sed -i 's/\.exe//g' "$PT_DIR/pt_config.json"
fi

chmod +x "$TOR_DIR/tor" 2>/dev/null || true
find "$PT_DIR" -type f ! -name '*.json' -exec chmod +x {} +
chmod +x "$SNOWFLAKE_DIR/snowflake-proxy"
[ -f "$ARTI_HOP_DIR/artihop" ] && chmod +x "$ARTI_HOP_DIR/artihop"

rm -rf "$TEMP_DIR"
echo "Done."
