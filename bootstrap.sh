#!/bin/bash
# Refference: https://opensource.com/article/20/5/disk-image-raspberry-pi
# Mount multiple partitions at the same time: https://unix.stackexchange.com/questions/82314/how-to-find-the-type-of-an-img-file-and-mount-it

sudo apt-get install qemu qemu-user-static binfmt-support -y

# ubuntu core
ubuntu_core="https://cdimage.ubuntu.com/ubuntu-core/20/stable/current/ubuntu-core-20-armhf+raspi.img.xz"

# ubuntu server
ubuntu_server="https://cdimage.ubuntu.com/releases/20.04.2/release/ubuntu-20.04.2-preinstalled-server-arm64+raspi.img.xz"

clear

bar="#############################################################"

echo $bar
echo Bootstrap Ubuntu Server image


# Check for decompressed image, if not download (<filename>.img.xz is renamed to <filename.img when decompressed)
if [ ! -f *.img ]; then
    echo Downloading Ubuntu Server for Rasperry Pi...
    wget -O raspi-ubuntu.img.xz $ubuntu_server
fi

# check that <filename>.img OR <filename>.img.xz exists, if not exit (That means download failed)
if [ ! -f *.img* ]; then
    echo No image found, exiting...
    echo $bar
    exit 1
fi

file=$(ls *.img*)
filename=$(echo $file | sed 's/.xz//')

# check if <filename>.img exists, if not decompress <filename>.img.xz
if [ ! -f $filename ]; then
    echo image saved as $file
    echo Decompressing $file as $filename
    xz --decompress $file
fi

# saving this for debugging purposes
# units=$(fdisk -l $filename | grep ^Units: |  awk -F" "  '{ print $8 }')
# start_sector=$(fdisk -l $filename | grep ^$filename |  awk -F" "  '{ print $3 }')
# offset=$((start_sector * units))


# Check if image is mounted, if not mount boot partition
if ! grep -qs "$pwd/mnt" /proc/mounts; then
    echo Mounting boot image...
    offset1=$(parted -sm $filename unit B print | column -s: -t | grep ^1 | awk -F" " '{ print $2 }' | sed 's/B//')
    sudo mount -t auto -o rw,loop,offset=$offset1 $filename mnt/boot

    # Update network configuration
    if ! grep -qs Hedwig mnt/boot/network-config; then
        echo Updating network configuration
        sudo bash -c 'cat <<EOF >> mnt/boot/network-config
        wifis:
        wlan0:
            dhcp4: true
            optional: true
            access-points:
            "<ssid>":
                password: "<password>"
        
    EOF'
    fi

    echo unmounting boot partition
    sudo bash -c "umount mnt/boot"
fi

# Check if image is mounted, if not mount linux partition
if ! grep -qs "$pwd/mnt" /proc/mounts; then
    echo Mounting linux image...
    offset2=$(parted -sm $filename unit B print | column -s: -t | grep ^2 | awk -F" " '{ print $2 }' | sed 's/B//')
    sudo mount -t auto -o rw,loop,offset=$offset2 $filename mnt/linux
    
    #######################
    # copy ssh certs into the correct directory

    # Steps needed in order to use host resources like network
    sudo cp /usr/bin/qemu-aarch64-static mnt/linux/usr/bin
    sudo cp /usr/bin/qemu-arm-static mnt/linux/usr/bin
    sudo cp /run/systemd/resolve/stub-resolv.conf etc/resolv.conf
    sudo mount --bind /dev mnt/linux/dev/
    sudo mount --bind /sys mnt/linux/sys/
    sudo mount --bind /proc mnt/linux/proc/
    sudo mount --bind /dev/pts mnt/linux/dev/pts
    
    # sudo chroot mnt/linux /usr/bin/uname -a -r
    sudo chroot mnt/linux groupadd -g -o 1000 jmiller
    sudo chroot mnt/linux groupadd -g -o 1001 docker
    sudo chroot mnt/linux useradd -m -s /bin/bash -g jmiller -G sudo, docker jmiller
    sudo chroot mnt/linux useradd -m -s /bin/bash -g docker ubuntu
    sudo chroot mnt/linux passwd jmiller
    sudo chroot mnt/linux passwd ubuntu
    # sudo chroot mnt/linux apt-get update
    # udo chroot mnt/linux apt-get install flatpak -y
    # sudo chroot mnt/linux snap install microk8s --classic

    sudo bash -c "umount mnt/linux"
fi

# echo "Changing root (chroot) to mounted filesystem"

# sudo chroot mnt/linux /usr/bin/uname -a -r

echo $bar