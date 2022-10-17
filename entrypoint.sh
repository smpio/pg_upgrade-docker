#!/bin/bash

set -eu
shopt -s extglob

default_jobs=$(getconf _NPROCESSORS_ONLN)
JOBS=${JOBS:-${default_jobs}}


if [ -d "$PGDATA/_source" ]; then
	echo '>>> Found unfinished upgrade session'
	source_version="$(cat "$PGDATA/_source/PG_VERSION")"
	target_version="$(cat "$PGDATA/_target/PG_VERSION")"
else
	source_version="$(cat "$PGDATA/PG_VERSION")"
	target_version="${1:-${TARGET_VERSION:-default}}"
	if [[ "$source_version" == "$target_version" ]]; then
		echo ">>> Source version is $source_version, nothing to do"
		exit 0
	fi
	mkdir "$PGDATA/_source" "$PGDATA/_target"
	chmod 700 "$PGDATA/_source" "$PGDATA/_target"
	mv "$PGDATA/"!(_source|_target) "$PGDATA/_source/"
fi

if [ ! -x "/usr/lib/postgresql/$source_version/bin/initdb" ]; then
	echo ">>> Unsupported PostgreSQL version: $source_version"
	exit 1
fi

if [ ! -x "/usr/lib/postgresql/$target_version/bin/initdb" ]; then
	echo ">>> Unsupported PostgreSQL version: $target_version"
	exit 1
fi

if [ ! -f "$PGDATA/_target/PG_VERSION" ]; then
	echo ">>> initdb $target_version"
	"/usr/lib/postgresql/$target_version/bin/initdb" --username="$PGUSER" "$PGDATA/_target"
fi

cd "$PGDATA/_target"

echo ">>> pg_upgrade $source_version -> $target_version"
(set -x; time "/usr/lib/postgresql/$target_version/bin/pg_upgrade" \
	--old-bindir="/usr/lib/postgresql/$source_version/bin" \
	--new-bindir="/usr/lib/postgresql/$target_version/bin" \
	--jobs="$JOBS" \
	--link \
	--old-datadir="$PGDATA/_source" \
	--new-datadir="$PGDATA/_target"
)

if [ -f "$PGDATA/_source/postgresql.auto.conf" ]; then
	echo ">>> save postgresql.auto.conf"
	(set -x; cp "$PGDATA/_source/postgresql.auto.conf" "$PGDATA/_target/")
fi

if [ -f "$PGDATA/_source/pg_hba.conf" ]; then
	echo ">>> save pg_hba.conf"
	(set -x; cp "$PGDATA/_source/pg_hba.conf" "$PGDATA/_target/")
fi

mv "$PGDATA/_target/"* "$PGDATA/"
rmdir "$PGDATA/_target"
rm -rf "$PGDATA/_source"

rm "$PGDATA/delete_old_cluster.sh" || true

echo "listen_addresses = '*'" >> "$PGDATA/postgresql.auto.conf"

echo ">>> Done!"
echo ">>> Warning! postgresql.conf is overwritten!"
