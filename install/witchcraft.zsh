#!/usr/bin/env zsh

tmpfile=$(mktemp)
cp "$HOME/Library/LaunchAgents/com.ulysse.witchcraft.plist" $tmpfile

m4 \
	-DHOME="$HOME" \
	-DCHROME_SCRIPT_PATH="${WITCHCRAFT_SCRIPT_PATH-$HOME/Dev/BuonOmo/chrome-scripts}" \
	-DPORT="5743" \
	$tmpfile > "$HOME/Library/LaunchAgents/com.ulysse.witchcraft.plist"

rm $tmpfile

[[ "${WITCHCRAFT_SCRIPT_PATH-x}" == x ]] && {
	mkdir -P "$HOME/Dev/BuonOmo"
	git clone git@github.com:BuonOmo/chrome-scripts.git "$HOME/Dev/BuonOmo/chrome-scripts"
}
