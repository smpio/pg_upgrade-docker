FROM debian:stretch

RUN set -eux; \
	apt-get update; \
	apt-get install -y locales; \
	echo en_US.UTF-8 UTF-8 >> /etc/locale.gen; \
	locale-gen; \
	rm -rf /var/lib/apt/lists/*

ENV LANG en_US.utf8

RUN set -eux; \
	groupadd -r postgres --gid=999; \
	useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
	mkdir -p /var/lib/postgresql; \
	chown -R postgres:postgres /var/lib/postgresql

RUN set -eux; \
	apt-get update; \
	apt-get install -y wget ca-certificates gnupg; \
	rm -rf /var/lib/apt/lists/*

ENV GOSU_VERSION 1.11
RUN set -x \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
	&& rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true

ENV TARGET_VERSION 12
RUN set -eux; \
	echo deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main > /etc/apt/sources.list.d/pgdg.list; \
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -; \
	apt-get update; \
	for version in 9.2 9.3 9.4 9.5 9.6 $(seq 10 $TARGET_VERSION); do \
		apt-get install -y postgresql-$version; \
	done; \
	rm -rf /var/lib/apt/lists/*; \
	rm -rf /var/lib/postgresql/*

COPY entrypoint.sh /
ENV PGDATA /var/lib/postgresql/data
ENTRYPOINT ["gosu", "postgres", "/entrypoint.sh"]
