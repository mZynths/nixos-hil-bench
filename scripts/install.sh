#!/usr/bin/env bash
# Bootstrap installer for nixos-hil-bench.
#
# Run from a NixOS live USB, from inside a clone of this repo:
#   git clone https://github.com/mZynths/nixos-hil-bench.git
#   cd nixos-hil-bench
#   sudo ./scripts/install.sh /dev/nvme0n1
#
# This WIPES the target disk. It partitions (GPT: 1GiB FAT32 ESP + the rest
# as btrfs), creates @/@home/@nix/@swap subvolumes with zstd compression,
# sets up a swapfile, generates hardware.nix, and runs nixos-install.
#
# NOT YET VERIFIED END-TO-END AS A SINGLE SCRIPT — encodes the steps (and
# fixes) from the first real install, done manually/interactively. Treat
# the next clean install as the real test of this script, and expect to
# iterate.

set -euo pipefail

DISK="${1:?Usage: $0 /dev/DISK (e.g. /dev/nvme0n1) — run lsblk first to find it}"
SWAP_SIZE_MB="${SWAP_SIZE_MB:-8192}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

echo "This will COMPLETELY ERASE $DISK."
echo "Type the disk name again to confirm:"
read -r CONFIRM
if [ "$CONFIRM" != "$DISK" ]; then
  echo "Confirmation did not match, aborting."
  exit 1
fi

# --- Partition ---------------------------------------------------------
parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart ESP fat32 1MiB 1GiB
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart primary 1GiB 100%

if [[ "$DISK" == *nvme* || "$DISK" == *mmcblk* ]]; then
  BOOT_PART="${DISK}p1"
  ROOT_PART="${DISK}p2"
else
  BOOT_PART="${DISK}1"
  ROOT_PART="${DISK}2"
fi

# --- Format --------------------------------------------------------------
mkfs.fat -F32 -n boot "$BOOT_PART"
mkfs.btrfs -f -L nixos "$ROOT_PART"

# --- Subvolumes ----------------------------------------------------------
mount "$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@swap
umount /mnt

MOUNT_OPTS="compress=zstd,noatime,ssd,discard=async"
mount -o "subvol=@,${MOUNT_OPTS}" "$ROOT_PART" /mnt
mkdir -p /mnt/home /mnt/nix /mnt/swap /mnt/boot
mount -o "subvol=@home,${MOUNT_OPTS}" "$ROOT_PART" /mnt/home
mount -o "subvol=@nix,${MOUNT_OPTS}" "$ROOT_PART" /mnt/nix
mount -o "subvol=@swap,noatime,ssd,discard=async" "$ROOT_PART" /mnt/swap
mount "$BOOT_PART" /mnt/boot

# --- Swapfile (no-cow required on btrfs, set before writing data) -------
truncate -s 0 /mnt/swap/swapfile
chattr +C /mnt/swap/swapfile
btrfs property set /mnt/swap/swapfile compression none
dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count="$SWAP_SIZE_MB" status=progress
chmod 600 /mnt/swap/swapfile
mkswap /mnt/swap/swapfile
swapon /mnt/swap/swapfile

# --- Hardware config -----------------------------------------------------
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix "$REPO_DIR/hosts/hil-laptop/hardware.nix"

# Flakes only see git-tracked files, even uncommitted ones — nixos-install
# fails otherwise with "Path ... is not tracked by Git".
git -C "$REPO_DIR" add hosts/hil-laptop/hardware.nix

# --- Install ---------------------------------------------------------------
# --no-root-passwd: the interactive passwd prompt at the end of
# nixos-install doesn't play well with non-interactive/scripted runs;
# passwords are set explicitly below instead.
nixos-install --root /mnt --flake "${REPO_DIR}#hil-laptop" --no-root-passwd

echo "Set a password for root:"
nixos-enter --root /mnt -c 'passwd root'
echo "Set a password for zynths:"
nixos-enter --root /mnt -c 'passwd zynths'

echo
echo "Install complete. Remove the USB drive and run: reboot"
