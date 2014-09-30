# pinkpogo

Default PogoOS Username: `root`

Default PogoOS Password: `ceadmin`

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

### "squeeze"

You might be wondering why we just installed squeeze instead of going straight for wheezy, jessie, or sid.

The answer is somewhat complicated, but it boils down to the kernel installed in the default PogoOS is too old to run the binaries included in wheezy+, so we have to get into squeeze, and from there upgrade ourselves to wheezy and beyond.

### "wheezy"

Once you're into your new "squeeze" system, open up `/etc/apt/sources.list` (`vim /etc/apt/sources.list`) and switch "squeeze" to "wheezy" (`:%s/squeeze/wheezy/g`).  Once that's done, do a full system upgrade (`apt-get update && apt-get dist-upgrade`).

This _should_ install an updated kernel as part of the changes, but it might not, so just to be sure, you should run something like `apt-get install linux-image-kirkwood`, which will make sure the 3.2.x kernel from wheezy is definitely installed and configured.

Once that's finished, reboot and make sure your device comes back up, and use `uname -a` to verify that your kernel is a 3.2+ kernel instead of that ancient 2.6 stuff that's in PogoOS and squeeze.

### "jessie"/"testing" or "sid"/"unstable"

At this point, feel free to repeat the above steps if you want to get to something even newer, like "jessie" (if you want to switch to current "testing"), "testing" (if you want perpetual "testing", even through jessie+1), or "sid" or "unstable" (if you want the latest and greatest packages or want to do some Debain packaging work like a proper Debian Hacker).

## netconsole

Important paths:
- `/usr/sbin/fw_setenv` (in PogoOS)
- `/usr/lib/u-boot/dockstar/fw_setenv` (in `u-boot-tools` package in Debian)

To help in diagnosing boot issues, netconsole is a great resource.

See http://forum.doozan.com/read.php?3,14,14 for more information, but the general gist is:

(Assuming your laptop or desktop box is at `192.168.1.2` and your pogo should assign itself to `192.168.1.100` during boot.)

```console
$ fw_setenv serverip 192.168.1.2
$ fw_setenv ipaddr 192.168.1.100
$ fw_setenv if_netconsole 'ping $serverip'
$ fw_setenv start_netconsole 'setenv ncip $serverip; setenv bootdelay 10; setenv stdin nc; setenv stdout nc; setenv stderr nc; version;'
$ fw_setenv preboot 'run if_netconsole start_netconsole'
```

If you need a netmask that's different from `255.255.255.0`, use something like:

```console
$ fw_setenv netmask 255.255.0.0
```

Then, run `./netconsole-server.sh` on your host box and reboot your Pogo.  With any luck, it'll give you some pretty output from the boot process and you'll be able to see (hopefully) some clues as to why your pretty new Debian install isn't booting!
