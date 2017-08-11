#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# FIXME
#mv $chroot/etc/cron.daily/logrotate $chroot/usr/bin/logrotate-cron
# logrotate package in sles12sp2 (and other versions before that) had this cron.daily
# file created automatically. It seems its no longer the case for the version in sles12sp3.
# We need to fix this in a better way for a proper solution.
cat <<'LOGROTATE_CRON' > $chroot/usr/bin/logrotate-cron
#!/bin/sh

# exit immediately if there is another instance running
if checkproc /usr/sbin/logrotate; then
        /bin/logger -p cron.warning -t logrotate "ALERT another instance of logrotate is running - exiting"
        exit 1
fi

TMPF=`mktemp /tmp/logrotate.XXXXXXXXXX`

/usr/sbin/logrotate /etc/logrotate.conf 2>&1 | tee $TMPF
EXITVALUE=${PIPESTATUS[0]}

if [ $EXITVALUE != 0 ]; then
    # wait a sec, we might just have restarted syslog
    sleep 1
    # tell what went wrong
    /bin/logger -p cron.warning -t logrotate "ALERT exited abnormally with [$EXITVALUE]"
    /bin/logger -p cron.warning -t logrotate -f $TMPF
 fi

rm -f $TMPF
exit 0
LOGROTATE_CRON

echo '0,15,30,45 * * * * root /usr/bin/logrotate-cron' > $chroot/etc/cron.d/logrotate

cp -f $assets_dir/default_su_directive $chroot/etc/logrotate.d/default_su_directive
