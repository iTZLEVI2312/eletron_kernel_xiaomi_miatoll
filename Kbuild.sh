#!/bin/bash
#
# Script For Building Android Kernel
# By iTZ_UDAY_2312
#

##----------------------------------------------------------##

KERNEL_DIR="$(pwd)"

##----------------------------------------------------------##

# Custom Kernel 
CUSTOM_KERNEL=eletron+
CUSTOM_VERSION=1.0_KSU
VENDOR=Xiaomi
DEVICE=MiAtoll

##----------------------------------------------------------##

# Date Today
DATE=$(TZ=Asia/Kolkata date +"%Y%m%d-%T")
TODAY=$(date +"%F%S")

FINAL_KERNEL_ZIP=${CUSTOM_KERNEL}-${CUSTOM_VERSION}-${DEVICE}-${TODAY}.zip

##----------------------------------------------------------##

# KFiles
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img

# Kernel
KERVER=$(make kernelversion)
COMPILER=proton-13 #Specify Clang/GCC
KERNEL_DEFCONFIG=miatoll_defconfig # defconfig

ANYKERNEL3_DIR=$PWD/AnyKernel3/
CCACHE=$(command -v ccache)
LINKER=ld.lld

# Verbose Build
VERBOSE=0

# Colors 
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
nocol='\033[0m'
NC='\033[0m'
RED='\033[0;31m'
LRD='\033[1;31m'
LGR='\033[1;32m'

##----------------------------------------------------------##

# Speed up build process
MAKE="./makeparallel"

# Clean build always
clean(){
    echo "$RED**** Cleaning Directory ****"
    mkdir -p out
    make O=out clean
}

##----------------------------------------------------------##

# Clone ToolChain
toolchain(){

	if [ $COMPILER = "atomx" ];
	then
        echo -e ${LGR} " Cloning Atomx Clang ToolChain ${NC}"
	git clone --depth=1 https://gitlab.com/ElectroPerf/atom-x-clang.git clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"

    elif [ $COMPILER = "neutron" ];
    then
        echo -e ${LGR} " Cloning Neutron Clang ToolChain ${NC}"
    git clone --depth=1 https://gitlab.com/dakkshesh07/neutron-clang.git clang
    PATH="${KERNEL_DIR}/clang/bin:$PATH"

	elif [ $COMPILER = "azure" ];
	then
        echo -e ${LGR} " Cloning Azure Clang ToolChain ${NC}"
	git clone --depth=1 https://gitlab.com/Panchajanya1999/azure-clang.git clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"

	elif [ $COMPILER = "proton-13" ];
	then
        echo -e ${LGR} " Cloning Proton Clang 13 ToolChain ${NC}"
	git clone --depth=1 https://github.com/kdrag0n/proton-clang.git clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"

    elif [ $COMPILER = "proton-15" ];
	then
	    echo -e ${LGR} " Cloning Proton Clang 15 ToolChain ${NC}"
	git clone --depth=1 https://gitlab.com/LeCmnGend/proton-clang.git clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"

	elif [ $COMPILER = "eva" ];
	then
        echo -e ${LGR} " Cloning Eva GCC ToolChain ${NC}"
	git clone --depth=1 https://github.com/mvaisakh/gcc-arm64.git gcc64
	git clone --depth=1 https://github.com/mvaisakh/gcc-arm.git gcc32
	PATH=$KERNEL_DIR/gcc64/bin/:$KERNEL_DIR/gcc32/bin/:/usr/bin:$PATH

	elif [ $COMPILER = "aosp" ];
	then
        echo -e ${LGR} " Cloning Aosp Clang 15.0.2 ToolChain ${NC}"
        mkdir aosp-clang
        cd aosp-clang || exit
	    wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r468909.tar.gz
        tar -xf clang*
        cd .. || exit
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git --depth=1 gcc
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git  --depth=1 gcc32
	PATH="${KERNEL_DIR}/aosp-clang/bin:${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:${PATH}"
	fi
}

##----------------------------------------------------------##

# KernelSU
ksu(){
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
}

##----------------------------------------------------------##

# Exports 
exports(){

        # Export KBUILD_COMPILER_STRING
        if [ -d ${KERNEL_DIR}/clang ];
            then
               export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
        elif [ -d ${KERNEL_DIR}/gcc64 ];
            then
               export KBUILD_COMPILER_STRING=$("$KERNEL_DIR/gcc64"/bin/aarch64-elf-gcc --version | head -n 1)
        elif [ -d ${KERNEL_DIR}/aosp-clang ];
            then
               export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/aosp-clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
        fi

        # Export ARCH and SUBARCH
        export ARCH=arm64
        export SUBARCH=arm64

        # KBUILD HOST and USER
        export KBUILD_BUILD_HOST=archlinux
        export KBUILD_BUILD_USER="iTZ_UDAY_2312"

        # CI
        if [ "$CI" ]
           then
            if [ "$CIRCLECI" ]
                then                  
                export CI_BRANCH=${CIRCLE_BRANCH}
            elif [ "$DRONE" ]
	            then		  
		        export CI_BRANCH=${DRONE_BRANCH}
            fi

        fi

	export PROCS=$(nproc --all)
	export DISTRO=$(source /etc/os-release && echo "${NAME}")
}

##----------------------------------------------------------------##

compile()
{
    BUILD_START=$(date +"%s")
    
    echo -e ${LGR} "########### Generating Defconfig ############${NC}"
    echo "******* Kernel defconfig is set to $KERNEL_DEFCONFIG *******"
    echo -e ${LGR} "#############################################${NC}"
    echo "."
    echo -e "$blue****************************************************"
    echo -e ${blue} "##             BUILDING KERNEL                 ##"
    echo -e "$blue***************************************************$nocol"
    
    echo "<b>$KBUILD_BUILD_VERSION CI Build Triggered</b>"
    echo "<b>DockerOS: </b> $DISTRO"
    echo "<b>Kernel Version : </b>$KERVER"
    echo "<b>Date : </b>$(TZ=Asia/Kolkata date) "
    echo "<b>Device : </b>$VENDOR [$DEVICE] "
    echo "<b>Version : </b>$CUSTOM_VERSION "
    echo "<b>Pipeline Host : </b>$KBUILD_BUILD_USER "
    echo "<b>Pipeline Host : </b>$KBUILD_BUILD_HOST "
    echo "<b>Host Core Count : </b> $PROCS "
    echo "<b>Compiler Used : </b> $KBUILD_COMPILER_STRING "
    echo "<b>Linker : </b>$LINKER "
	
    # Make Defconfig
    make O=out ARCH=${ARCH} ${KERNEL_DEFCONFIG}
    
    # Compile
    echo -e ${LGR} "######### Compiling kernel #########${NC}"

    if [ -d ${KERNEL_DIR}/clang ];
	   then
	       make -kj$(nproc --all) O=out \
	       ARCH=${ARCH} \
	       CC=clang \
	       HOSTCC=clang \
	       HOSTCXX=clang++ \
	       CROSS_COMPILE=aarch64-linux-gnu- \
	       CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
	       LD=${LINKER} \
	       AR=llvm-ar \
	       NM=llvm-nm \
	       OBJCOPY=llvm-objcopy \
	       OBJDUMP=llvm-objdump \
	       STRIP=llvm-strip \
	       READELF=llvm-readelf \
	       OBJSIZE=llvm-size \
	       V=$VERBOSE 2>&1 | tee error.log
	elif [ -d ${KERNEL_DIR}/gcc64 ];
	   then
	       make -kj$(nproc --all) O=out \
	       ARCH=${ARCH} \
	       CROSS_COMPILE_ARM32=arm-eabi- \
	       CROSS_COMPILE=aarch64-elf- \
	       LD=aarch64-elf-${LINKER} \
	       AR=llvm-ar \
	       NM=llvm-nm \
	       OBJCOPY=llvm-objcopy \
	       OBJDUMP=llvm-objdump \
	       STRIP=llvm-strip \
	       OBJSIZE=llvm-size \
	       V=$VERBOSE 2>&1 | tee error.log
    elif [ -d ${KERNEL_DIR}/aosp-clang ];
        then
            make -kj$(nproc --all) O=out \
	       ARCH=${ARCH} \
	       CC=clang \
           HOSTCC=clang \
	       HOSTCXX=clang++ \
	       CLANG_TRIPLE=aarch64-linux-gnu- \
	       CROSS_COMPILE=aarch64-linux-android- \
	       CROSS_COMPILE_ARM32=arm-linux-androideabi- \
           LD=${LINKER} \
           AR=llvm-ar \
           NM=llvm-nm \
           OBJCOPY=llvm-objcopy \
           OBJDUMP=llvm-objdump \
           STRIP=llvm-strip \
           READELF=llvm-readelf \
           OBJSIZE=llvm-size \
	       V=$VERBOSE 2>&1 | tee error.log
    fi

	# Verify Files
	if ! [ -a "$IMAGE" ];
	   then
           ERROR_LOG=$(cat error.log | curl -F 'f:1=<-' ix.io)
           ERROR_LOG2=$(curl --upload-file error.log https://free.keep.sh)
           echo -e ${RED} "#################################################"
           echo -e ${RED} "##          Error While Compiling :(           ##"
           echo -e ${RED} "##  ERROR LOG: $ERROR_LOG                      ##"
           echo -e ${RED} "##  ERROR LOG: $ERROR_LOG2                      ##"
           echo -e ${RED} "############################################${NC}"
	       exit 1
	    else
            echo -e ${LGR} "####################################################"
            echo -e ${LGR} "## Compilation Finished.Verifying for Zipping! :) ##"
            echo -e ${LGR} "################################################${NC}"

	fi
}

##----------------------------------------------------------##

verify(){
    echo "**** Verifying Image.gz-dtb & dtbo.img ****"
    ls $IMAGE
    ls $DTBO
    echo "**** Verifying AnyKernel3 Directory ****"
    ls $ANYKERNEL3_DIR
    echo "**** Removing leftovers ****"
    rm -rf $ANYKERNEL3_DIR/Image.gz-dtb
    rm -rf $ANYKERNEL3_DIR/dtbo.img
    rm -rf $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP
}

##----------------------------------------------------------##

completion()
{
    echo "**** Copying Image.gz-dtb & dtbo.img ****"
    cp $IMAGE $ANYKERNEL3_DIR/
    cp $DTBO $ANYKERNEL3_DIR/

    echo "**** Time to zip up! ****"
    cd $ANYKERNEL3_DIR/ || exit 1
    zip -r9 "../$FINAL_KERNEL_ZIP" * -x .github README.md
    cd ..

    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))

    echo "****Build Zipped, removing directories... ***"
    rm -rf $ANYKERNEL3_DIR
    rm -rf out

    echo "**** Done, Extracting MD5 Hash.....  ****"
    MD5CHECK=$(md5sum "$FINAL_KERNEL_ZIP" | cut -d' ' -f1)

    # Push Build
    DOWNLOAD_LINK=$(curl --upload-file $FINAL_KERNEL_ZIP https://free.keep.sh)
    echo ""
    echo -e ${LGR} "#####################################################################"
    echo -e ${LGR} "            Flabhable ZIP: $DOWNLOAD_LINK                            "
    echo -e ${LGR} " Build took : $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)"
    echo -e ${LGR} "       <b>MD5 Checksum : </b><code>$MD5CHECK                         "
    echo -e ${LGR} "      For <b>$VENDOR ($DEVICE)</b>                                   "
    echo -e ${LGR} "################################################################${NC}"

}

##----------------------------------------------------------##

# Execute
clean
toolchain
ksu
exports
compile
verify
completion

#-----------------------------------------------#
#-----------------------------------------------#
