#!/usr/bin/env bash
 
git config --global user.email "dhruvgera61@gmail.com"
git config --global user.name "Dhruv"
 
export TZ="Asia/Kolkata";
 
# Kernel compiling script
mkdir -p $HOME/TC
git clone git://github.com/RaphielGang/aarch64-linux-gnu-8.x $HOME/TC/aarch64-linux-gnu-8.x --depth=1
git clone git://github.com/VRanger/dragontc $HOME/TC/clang --depth=1
 
 
function check_toolchain() {
 
    export TC="$(find ${TOOLCHAIN}/bin -type f -name *-gcc)";
 
    if [[ -f "${TC}" ]]; then
        export CROSS_COMPILE="${TOOLCHAIN}/bin/$(echo ${TC} | awk -F '/' '{print $NF'} |\
sed -e 's/gcc//')";
        echo -e "Using toolchain: $(${CROSS_COMPILE}gcc --version | head -1)";
    else
        echo -e "No suitable toolchain found in ${TOOLCHAIN}";
        exit 1;
    fi
}
 
 
function sendlog {
    # var=$(php -r "echo file_get_contents('$1');")
    var="$(cat $1)"
    content=$(curl -sf --data-binary "$var" https://del.dog/documents)
    file=$(jq -r .key <<< $content)
    log="https://del.dog/$file"
    echo "URL is: "$log" "
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="Build failed, "$1" "$log" :3" -d chat_id=$CHAT_ID
}
 
function trimlog {
    sendlog "$1"
    grep -iE 'crash|error|fail|fatal' "$1" &> "trimmed$1"
    sendlog "trimmed_$1"
}
 
function transfer() {
    zipname="$(echo $1 | awk -F '/' '{print $NF}')";
    url="$(curl -# -T $1 https://transfer.sh)";
    printf '\n';
    echo -e "Download ${zipname} at ${url}";
}
 
if [[ -z ${KERNELDIR} ]]; then
    echo -e "Please set KERNELDIR";
    exit 1;
fi
 
export DEVICE=$1;
if [[ -z ${DEVICE} ]]; then
    export DEVICE="HM4X";
fi
 
mkdir -p ${KERNELDIR}/aroma
mkdir -p ${KERNELDIR}/files
 
export SRCDIR="${KERNELDIR}";
export OUTDIR="${KERNELDIR}/out";
export ANYKERNEL="${KERNELDIR}/AnyKernel2";
export AROMA="${KERNELDIR}/aroma/";
export ARCH="arm64";
export SUBARCH="arm64";
export KBUILD_BUILD_USER="Dhruv007"
export KBUILD_BUILD_HOST="TeamQuantum"
export TOOLCHAIN="$HOME/TC/aarch64-linux-gnu-8.x";
export DEFCONFIG="santoni_defconfig";
export ZIP_DIR="${HOME}/${KERNELDIR}/files";
export IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image.gz-dtb";
export CHAT_ID="-1001344943713";
export BOT_API_KEY="780524065:AAHoWvNA0Z3TrzNboNX3wUzUvHZpFLyUKb0"
#  Clang
if [[ "$*" == *"-clang"* ]]
then
  USE_CLANG=1
  export CC=$HOME/TC/clang/bin/clang
  export CLANG_VERSION=$($CC --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
  export CLANG_TRIPLE=aarch64-linux-gnu-
  export CLANG_LD_PATH=$HOME/TC/clang/lib
  export LLVM_DIS=$HOME/TC/clang/bin/llvm-dis
fi
 
export MAKE_TYPE="Treble"
 
if [[ -z "${JOBS}" ]]; then
    export JOBS="$(nproc --all)";
fi
 
export MAKE="make O=${OUTDIR}";
check_toolchain;
 
export TCVERSION1="$(${CROSS_COMPILE}gcc --version | head -1 |\
awk -F '(' '{print $2}' | awk '{print tolower($1)}')"
export TCVERSION2="$(${CROSS_COMPILE}gcc --version | head -1 |\
awk -F ')' '{print $2}' | awk '{print tolower($1)}')"
 
if [ -n "$USE_CLANG" ]
then
  export ZIPNAME="${KERNELNAME}-Clang-${MAKE_TYPE}$(date +%m%d-%H).zip"
else
  export ZIPNAME="${KERNELNAME}-${MAKE_TYPE}$(date +%m%d-%H).zip"
fi
export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"
 
[ ! -d "${ZIP_DIR}" ] && mkdir -pv ${ZIP_DIR}
[ ! -d "${OUTDIR}" ] && mkdir -pv ${OUTDIR}
 
cd "${SRCDIR}";
rm -fv ${IMAGE};
 
MAKE_STATEMENT=make
 
# Menuconfig configuration
# ================
# If -no-menuconfig flag is present we will skip the kernel configuration step.
# Make operation will use santoni_defconfig directly.
if [[ "$*" == *"-no-menuconfig"* ]]
then
  NO_MENUCONFIG=1
  MAKE_STATEMENT="$MAKE_STATEMENT KCONFIG_CONFIG=./arch/arm64/configs/santoni_defconfig"
fi
 
if [[ "$@" =~ "mrproper" ]]; then
    ${MAKE} mrproper
fi
 
if [[ "$@" =~ "clean" ]]; then
    ${MAKE} clean
fi
 
 
# Send Message about build started
# ================
curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="Build Scheduled for $KERNELNAME Kernel (${MAKE_TYPE})" -d chat_id=$CHAT_ID
 
 
 
cd $KERNELDIR
${MAKE} $DEFCONFIG;
START=$(date +"%s");
echo -e "Using ${JOBS} threads to compile"
 
# Check for Clang
# ================
if [ -n "$USE_CLANG" ]
then
 export KCFLAGS="-mllvm -polly -mllvm -polly-run-dce -mllvm -polly-run-inliner -mllvm -polly-opt-fusion=max -mllvm -polly-ast-use-context -mllvm -polly-vectorizer=stripmine -mllvm -polly-detect-keep-going -Wasm-operand-widths -Werror=duplicate-decl-specifier -Werror=stringop-overflow= -Werror=misleading-indentation  -Wsometimes-uninitialized"
  ${MAKE} -j${JOBS} ARCH=$ARCH CC=$CC CLANG_TRIPLE=$CLANG_TRIPLE CROSS_COMPILE=$CROSS_COMPILE KCFLAGS="$KCFLAGS" | tee build-log.txt ;
else
  ${MAKE} -j${JOBS} 2>&1 | tee build-log.txt ;
fi
 
 
exitCode="$?";
END=$(date +"%s")
DIFF=$(($END - $START))
echo -e "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.";
 
# Send log and trimmed log if build failed
# ================
if [[ ! -f "${IMAGE}" ]]; then
    echo -e "Build failed :P";
    trimlog build-log.txt
    success=false;
    exit 1;
else
    echo -e "Build Succesful!";
    success=true;
fi
 
# Make ZIP using AnyKernel
# ================
echo -e "Copying kernel image";
cp -v "${IMAGE}" "${ANYKERNEL}/Image.gz-dtb";
cd -;
cd ${ANYKERNEL};
mv Image.gz-dtb zImage
zip -r9 ${FINAL_ZIP} *;
cd -;
 
# Push to transfer.sh if successful
# ================
if [ -f "$FINAL_ZIP" ];
then
  if [[ ${success} == true ]]; then
      echo -e "Uploading ${ZIPNAME} to https://transfer.sh/";
      transfer "${FINAL_ZIP}";
   
 
message="CI build of Rockstar Kernel completed with the latest commit."

time="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."

#curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="$(git log --pretty=format:'%h : %s' -5)" -d chat_id=$CHAT_ID

curl -F chat_id="-1001344943713-F" document=@"${ZIP_DIR}/$ZIPNAME" -F caption="$message $time" https://api.telegram.org/bot$BOT_API_KEY/sendDocument

curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="

♔♔♔♔♔♔♔BUILD-DETAILS♔♔♔♔♔♔♔

🖋️ Author     : DhruvGera

🛠️ Make-Type  : $MAKE_TYPE

🗒️ Buld-Type  : TEST

⌚ Build-Time : $time

🗒️ Zip-Name   : $ZIPNAME

"  -d chat_id=$CHAT_ID
# curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="CAADBQADFQADIIRIEhVlVOIt6EkuAgc"  -d chat_id=$CHAT_ID
# curl -F document=@$url caption="Latest Build." https://api.telegram.org/bot$BOT_API_KEY/sendDocument -d chat_id=$CHAT_ID
 
 
fi
else
echo -e "Zip Creation Failed  ";
fi
