# mobian-recipes

A build script over a set of [debos/Debian OS builder](https://github.com/go-debos/debos) recipes for building a
Debian-based image for mobile devices, initially targetting PINE64's PinePhone. There is support now for PinePhone Pro,
Purism's Librem5, UEFI x86_64, OnePlus 6 and xiaomi pocof1 devices, and more.

Automated image builds are distributed and available [here](https://images.mobian-project.org/).

The default user is `mobian` with password `1234`.

**[The Developer's Guide page on the Wiki](https://gitlab.com/mobian1/wiki/-/wikis/Developer's-Guide) is a good place find more information.**

## Build

### Prerequisites, Notes

Prerequisites to building the image are [`debos`](https://github.com/go-debos/debos#synopsis), and (optionally)
[`bmaptool`](https://github.com/intel/bmap-tools#usage) and `squashfs-tools-ng`/`tar2sqfs`(for installer image).

On a Debian-based host, this command will satisfy the prerequisites; in a terminal:

```
sudo su -c "apt install debos bmap-tools squashfs-tools-ng"
```

__Do note__ that the debos provided in Debian 10 (Buster) is not new enough
(it will error out with "Unknown action: recipe"), the one in Debian
Bullseye works.

If your system isn't Debian-based (or if you choose to install `debos` without
using `apt`, which is a terrible idea), please make sure you also install the
following required packages:
- `debootstrap`
- `qemu-system-x86`
- `qemu-user-static`
- `binfmt-support`
- `squashfs-tools-ng` (only required for generating installer images)

The build system will cache and re-use it's output files. To create a fresh build
remove `*.tar.gz`, `*.sqfs` and `*.img` before starting the build.

You can use `./build.sh -d` to execute `debos` via Docker, and full usage help is available via `./build.sh -?`.

### Building QEMU image

You can build a QEMU x86_64 image by adding the `-t amd64` (UEFI) or
`-t amd64-legacy` (BIOS) flags to `build.sh`

The resulting files are raw images. You can start qemu like so:

```
qemu-system-x86_64 -drive format=raw,file=<imagefile.img> -enable-kvm -cpu host -vga virtio -m 2048 -smp cores=4 -bios <uefi-firmware>
```
If you have built the BIOS image you can drop the `-bios <uefi-firmware>` flag.
On a gentoo system f.e. the uefi firmware can be found under
`/usr/share/edk2-ovmf/OVMF_CODE.fd`

You may also want to convert the raw image to qcow2 format
and resize it like this:

```
qemu-img convert -f raw -O qcow2 <raw_image.img> <qcow_image.qcow2>
qemu-img resize -f qcow2 <qcow_image.qcow2> +20G
```

## Install

Insert a MicroSD card into your computer, and type the following command:

```
sudo su -c "bmaptool copy $(pwd)/<image> /dev/<sdcard>"
```

or:

```
sudo su -c "dd if=$(pwd)/<image> of=/dev/<sdcard> bs=1M"
```

*Note: Make sure to use your actual SD card device, such as `mmcblk0` instead of
`<sdcard>`.*

**CAUTION: This will format the SD card and erase all its contents!!!**

## Third-party software

The project's Wiki provides
[a list](https://gitlab.com/mobian1/wiki/-/wikis/Software) of software
packages modified or created to work on mobile devices.

## Contributing

If you want to help with this project, please have a look at the
[roadmap](https://gitlab.com/mobian1/wiki/-/wikis/Development-Roadmap) and
[open issues](https://gitlab.com/mobian1/issues).

In case you need more information, feel free to get in touch with the developers
on the Pine64 [forum](https://forum.pine64.org/showthread.php?tid=9016) and/or
[#mobian:matrix.org](https://matrix.to/#/#mobian:matrix.org).

# License

This software is licensed under the terms of the GNU General Public License,
version 3.
