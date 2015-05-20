#! /bin/sh

# Include defaults if available
if [ -f /etc/default/open-iscsi ]; then
	. /etc/default/open-iscsi
fi

umount_fail=0

if [ $HANDLE_NETDEV -eq 1 ]; then
	echo "Unmounting all devices marked _netdev";
	umount -a -O _netdev >/dev/null 2>&1
fi


# Now handle iSCSI LVM Volumes
if [ -n "$LVMGROUPS" ]; then
	echo "Deactivating iSCSI volume groups"
	for vg in "$LVMGROUPS"; do
		vgchange --available=n $vg
		if [ $? -ne 0 ]; then
			echo "Cannot deactivate Volume Group $vg" >&2
			umount_fail=1
		fi
	done
fi

for HOST_DIR in /sys/devices/platform/host*; do
	if ! [ -d $HOST_DIR/iscsi_host* ]; then
		continue
	fi
	for SESSION_DIR in $HOST_DIR/session*; do
		if ! [ -d $SESSION_DIR/target* ]; then
			continue
		fi
		for BLOCK_FILE in $SESSION_DIR/target*/*\:*/block/*; do
			BLOCK_DEV=`echo "$BLOCK_FILE" | sed 's/.*block\///'`
			if [ "${BLOCK_DEV}" = "*" ];then
				echo "iSCSI target without block devices found" >&2
				continue
			fi
			DOS_PARTITIONS="`grep "^/dev/$BLOCK_DEV" /proc/mounts | while read dev mp other ; do echo $mp ; done`"
			for DEVICE in $DOS_PARTITIONS; do
				umount $DEVICE
				exit_status=$?
				if ! [ $exit_status -eq 0 ]; then
					umount_fail=1
					echo "Could not unmount $DEVICE" >&2
				fi
			done
		done
	done
done

exit $umount_fail
