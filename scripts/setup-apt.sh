#!/bin/sh

set -ex

LOCAL_DEBS_DIR="/usr/local/debs"

DEBIAN_SUITE=$1
SUITE=$2
CONTRIB=$3
NONFREE=$4
LOCAL_DEBS_PATTERN=$5

COMPONENTS="main"
[ "$CONTRIB" = "true" ] && COMPONENTS="$COMPONENTS contrib"
[ "$NONFREE" = "true" ] && COMPONENTS="$COMPONENTS non-free"

# Add debian-security for bullseye; note that only the main component is supported
if [ "$DEBIAN_SUITE" = "bullseye" ]; then
    echo "deb http://security.debian.org/ $DEBIAN_SUITE-security $COMPONENTS" >> /etc/apt/sources.list
fi

# Set the proper suite in our sources.list
sed -i "s/@@SUITE@@/${SUITE}/" /etc/apt/sources.list.d/mobian.list

# Setup repo priorities so mobian comes first
cat > /etc/apt/preferences.d/00-mobian-priority << EOF
Package: *
Pin: release o=Mobian
Pin-Priority: 700
EOF

# install any build-local provided packages
[ "$LOCAL_DEBS_PATTERN" ] && \
    echo "Slip-streaming build-local packages matching pattern: $LOCAL_DEBS_PATTERN" && \
    ls -d $LOCAL_DEBS_DIR/$LOCAL_DEBS_PATTERN && \
    apt-get -q update && \
    DEBIAN_FRONTEND=noninteractive apt-get -q -y --no-install-recommends install $LOCAL_DEBS_DIR/$LOCAL_DEBS_PATTERN
rm -rf $LOCAL_DEBS_DIR
