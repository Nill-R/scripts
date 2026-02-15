#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

set -eu
snap list --all | awk '/disabled/{print $1, $3}' |
	while read -r snapname revision; do
		snap remove "$snapname" --revision="$revision"
	done

exit 0
