#!/bin/sh

rm modules.* Module.symvers .missing-syscalls.d .version
rm -f arch/arm/boot/zImage zImage arch/arm/boot/compressed/*.o arch/arm/boot/compressed/.*.cmd arch/arm/boot/compressed/vmlinux arch/arm/boot/compressed/piggy.xzkern arch/arm/boot/compressed/ashldi3.S arch/arm/boot/compressed/vmlinux.lds arch/arm/boot/compressed/lib1funcs.S arch/arm/boot/Image arch/arm/boot/.*.cmd 
rm -rf .tmp* .vm* ..tmp* vmlinux* System.map usr/.initramfs_data.* usr/*.o usr/.*.cmd usr/initramfs_data.cpio usr/gen_init_cpio usr/modules.* init/*.o init/.*.cmd init/modules.*

export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE=`readlink -f $KERNELDIR/../ramfs-sgs3`
export PARENT_DIR=`readlink -f ..`
export USE_SEC_FIPS_MODE=true
# GCC 4.7.2
export CROSS_COMPILE=$PARENT_DIR/../arm-2012/bin_472/arm-linux-

if [ "${1}" != "" ];then
  export KERNELDIR=`readlink -f ${1}`
fi

RAMFS_TMP="/tmp/ramfs-source-sgs3"

if [ ! -f $KERNELDIR/.config ];
then
  make bgn9000_defconfig
fi

. $KERNELDIR/.config

export ARCH=arm

cd $KERNELDIR/
nice -n 10 make -j4 || exit 1

#remove previous ramfs files
rm -rf $RAMFS_TMP
rm -rf $RAMFS_TMP.cpio
rm -rf $RAMFS_TMP.cpio.xz
#copy ramfs files to tmp directory
cp -ax $RAMFS_SOURCE $RAMFS_TMP
#clear git repositories in ramfs
find $RAMFS_TMP -name .git -exec rm -rf {} \;
#remove empty directory placeholders
find $RAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rf {} \;
rm -rf $RAMFS_TMP/tmp/*
#remove mercurial repository
rm -rf $RAMFS_TMP/.hg
#copy modules into ramfs
mkdir -p $INITRAMFS/lib/modules
mv -f drivers/media/video/samsung/mali_r3p0_lsi/mali.ko drivers/media/video/samsung/mali_r3p0_lsi/mali_r3p0_lsi.ko
mv -f drivers/net/wireless/bcmdhd.cm/dhd.ko drivers/net/wireless/bcmdhd.cm/dhd_cm.ko
find -name '*.ko' -exec cp -av {} $RAMFS_TMP/lib/modules/ \;
${CROSS_COMPILE}strip --strip-unneeded $RAMFS_TMP/lib/modules/*

cd $RAMFS_TMP
find | fakeroot cpio -H newc -o > $RAMFS_TMP.cpio 2>/dev/null
ls -lh $RAMFS_TMP.cpio
#gzip -9 $RAMFS_TMP.cpio
xz --check=crc32 --lzma2=dict=1MiB $RAMFS_TMP.cpio
cd -

nice -n 10 make -j3 zImage || exit 1

./mkbootimg --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.xz --board smdk4x12 --base 0x10000000 --pagesize 2048 --ramdiskaddr 0x11000000 -o $KERNELDIR/boot.img.pre

$KERNELDIR/mkshbootimg.py $KERNELDIR/boot.img $KERNELDIR/boot.img.pre $KERNELDIR/payload.tar
rm -f $KERNELDIR/boot.img.pre

