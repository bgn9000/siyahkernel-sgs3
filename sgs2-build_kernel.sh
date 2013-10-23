#!/bin/sh

rm modules.* Module.symvers .missing-syscalls.d .version
rm -f arch/arm/boot/zImage zImage arch/arm/boot/compressed/*.o arch/arm/boot/compressed/.*.cmd arch/arm/boot/compressed/vmlinux arch/arm/boot/compressed/piggy.xzkern arch/arm/boot/compressed/ashldi3.S arch/arm/boot/compressed/vmlinux.lds arch/arm/boot/compressed/lib1funcs.S arch/arm/boot/Image arch/arm/boot/.*.cmd 
rm -rf .tmp* .vm* ..tmp* vmlinux* System.map usr/.initramfs_data.* usr/*.o usr/.*.cmd usr/initramfs_data.cpio usr/gen_init_cpio usr/modules.* init/*.o init/.*.cmd init/modules.*

export KERNELDIR=`readlink -f .`
export INITRAMFS_SOURCE=`readlink -f ~/Kernels/SGS2/initramfs`
export PARENT_DIR=`readlink -f ..`
export USE_SEC_FIPS_MODE=true
# GCC 4.7.2
export CROSS_COMPILE=$PARENT_DIR/../arm-2012/bin_472/arm-linux-gnueabihf-

if [ "${1}" != "" ];then
  export KERNELDIR=`readlink -f ${1}`
fi

INITRAMFS_TMP="/tmp/initramfs-source"

if [ ! -f $KERNELDIR/.config ];
then
  make bgn9000_s2_defconfig
fi

. $KERNELDIR/.config

export ARCH=arm

cd $KERNELDIR/
nice -n 10 make -j4 || exit 1

echo initramfs...
rm -rf $INITRAMFS_TMP
rm -rf $INITRAMFS_TMP.cpio
mkdir $INITRAMFS_TMP
mkdir $INITRAMFS_TMP/lib
mkdir $INITRAMFS_TMP/lib/modules/

cd initramfs/
tar cvf $INITRAMFS_TMP/initramfs.tar *
cd ..
cd $INITRAMFS_TMP
tar xvf initramfs.tar
rm initramfs.tar
cd -
find $INITRAMFS_TMP -name .git -exec rm -rf {} \;
find -name '*.ko' -exec cp -av {} $INITRAMFS_TMP/lib/modules/ \;
cd $INITRAMFS_TMP
find | fakeroot cpio -H newc -o > $INITRAMFS_TMP.cpio 2>/dev/null
ls -lh $INITRAMFS_TMP.cpio
cd -

echo compiling kernel...
nice -n 10 make -j4 zImage CONFIG_INITRAMFS_SOURCE="$INITRAMFS_TMP.cpio" || exit 1
$KERNELDIR/mkshbootimg.py $KERNELDIR/zImage $KERNELDIR/arch/arm/boot/zImage $KERNELDIR/payload.tar

