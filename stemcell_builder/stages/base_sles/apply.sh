#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

rm -r $chroot
kiwicompat --prepare $base_dir/stages/base_sles --root $chroot

cp /etc/resolv.conf $chroot/etc/resolv.conf
cp $assets_dir/runit.service $chroot/usr/lib/systemd/system/
cp $assets_dir/dkms-2.2.0.3-16.1.noarch.rpm $chroot/tmp
cp $assets_dir/runit-2.1.2.tar.gz $chroot/tmp
cp $assets_dir/ubuntu-certificates.run $chroot/usr/lib/ca-certificates/update.d/99x_ubuntu_certs.run
chmod +x $chroot/usr/lib/ca-certificates/update.d/99x_ubuntu_certs.run

dd if=/dev/urandom of=$chroot/var/lib/random-seed bs=512 count=1

run_in_chroot $chroot "
sed -i 's/# installRecommends = yes/installRecommends = no/' /etc/zypp/zypper.conf
zypper --gpg-auto-import-keys ref

groupadd adm
groupadd dip
systemctl enable runit || true # TODO figure out why enable always returns non-zero exit code

# Losen pam_limits limits for the vcap user
# That is necessary for properly running the mysql server, for example
echo 'vcap  soft  nproc  4096' >> /etc/security/limits.conf
echo 'vcap  hard  nproc  4096' >> /etc/security/limits.conf

rpm -Uhv /tmp/dkms-2.2.0.3-16.1.noarch.rpm
rm /tmp/dkms-2.2.0.3-16.1.noarch.rpm

rm -rf /lib/modules/4.1.12-1-pv/
rm -rf /lib/modules/4.1.12-1-xen/

# Make sure that SSH host keys are generated. By default they are only generated if there is no
# specific HostKey configuration in /etc/ssh/sshd_config
sed -i 's@if .*;@if true;@' /usr/sbin/sshd-gen-keys-start

# Delete the hosts.equiv trust file (STIG V-38491)
rm /etc/hosts.equiv

# Explicitly enable zypper's gpgcheck
echo 'gpgcheck = on' >> /etc/zypp/zypp.conf
"

touch ${chroot}/etc/gshadow

# This is required for the bosh_go_agent stage
mkdir -p $chroot/etc/service/

run_in_chroot $chroot "
  ln -s /etc/sv /service

  # Enable nf_conntrack module
  echo "nf_conntrack" > /etc/modules-load.d/conntrack.conf
"

locale_file=/etc/locale.conf

echo "LANG=\"en_US.UTF-8\"" >> ${chroot}/${locale_file}

# Apply security rules
truncate -s0 $chroot/etc/motd # CIS-11.1
