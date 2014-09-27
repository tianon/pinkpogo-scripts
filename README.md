# pinkpogo

Default Username: `root`

Default Password: `ceadmin`

If you find yourself locked out and SSH connections are being refused, the firmware in your box probably updated itself.  Go to http://pogoplug.com, create an account, activate your device, then go into your Security Settings and enable SSH on the box again.

## uBoot

First, you'll want to swap your bootloader to a newer uBoot.  Follow the instructions at http://projects.doozan.com/uboot/ for that.

ie: (as of 2014-09-26, so double check the site before running)

```console
$ cd /tmp
$ wget http://projects.doozan.com/uboot/install_uboot_mtd0.sh
$ chmod +x install_uboot_mtd0.sh
$ ./install_uboot_mtd0.sh
```

## Debian

Plug your USB stick into your computer and make two partitions on it with `gparted` or a similar tool.

The first partition should be the bigger one, and it'll be the root of the drive.  It needs to be formatted as `ext3`, since the pogoplug firmware doesn't have support for `ext4`.

The second partition will be your swap (and you need to format it as `linux swap`).  On size for that partition, YMMV, but bigger is better since otherwise your apps will all get OOM-killed if they run out of RAM (which the pogoplug has very little of).

Once you've got it partitioned and formatted, eject it and plug it into your pogoplug.

Now that you're back on the pogoplug, run `/sbin/fdisk -l /dev/sda` to make sure `/dev/sda` is your drive and that `/dev/sda1` is your root partition (`ext3`) and `/dev/sda2` is your swap partition (`linux swap`).

Run something like this:

```console
$ cd /tmp
$ wget https://raw.githubusercontent.com/tianon/pinkpogo-scripts/master/debootstrap-squeeze.sh
$ chmod +x debootstrap-squeeze.sh
$ vi debootstrap-squeeze.sh # if you need to modify the variables at the top of the script after the comment
$ ./debootstrap-squeeze.sh
```

Once that finishes, you'll have Debian installed on your USB stick and you should be ready to reboot into it! :)
