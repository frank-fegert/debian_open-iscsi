#!/bin/sh
#
# This script activates storage at boot after the iSCSI login. It can
# be called from both the init script as well as the native systemd
# service.
#

PATH=/sbin:/bin

MULTIPATH=/sbin/multipath
VGCHANGE=/sbin/vgchange

if [ -f /etc/default/open-iscsi ]; then
	. /etc/default/open-iscsi
fi

# Make sure we pick up all devices
udevadm settle || true

# Handle multipath
if [ -x $MULTIPATH ] ; then
	# If multipath is used, we might need to do udevadm settle
	# twice to make sure multipathd has seen the devices and
	# then been able to create the mappings.
	# (We assume that multipathd is already running.)
	sleep 0.1
	udevadm settle || true
fi

# Handle LVM
if [ ! -x $VGCHANGE ] && [ -n "$LVMGROUPS" ]; then
	echo "Warning: LVM2 tools are not installed, not honouring LVMGROUPS." >&2
	LVMGROUPS=""
fi

if [ -n "$LVMGROUPS" ] ; then
	if ! $VGCHANGE -ay $LVMGROUPS ; then
		echo "Warning: could not activate all LVM groups." >&2
	fi
	# Make sure we pick up all LVM devices
	udevadm settle || true
fi

# Mount all network filesystems
# (systemd takes care of it directly, so don't do it there)
if ! [ -d /run/systemd/system ] ; then
	if [ $HANDLE_NETDEV -eq 1 ] ; then
		mount -a -O _netdev >/dev/null 2>&1 || true
		# FIXME: should we really support swap on iSCSI?
		#        If so, we should update umountiscsi.sh!
		swapon -a -e >/dev/null 2>&1 || true
	fi
fi
