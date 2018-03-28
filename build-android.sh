#!/bin/bash
# Copyright (C) 2010 Mystic Tree Games
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Moritz "Moss" Wundke (b.thax.dcg@gmail.com)
#
# <License>
#
# Build boost for android completly. It will download boost 1.45.0
# prepare the build system and finally build it for android

# Add common build methods
. `dirname $0`/build-common.sh

# -----------------------
# Command line arguments
# -----------------------

ABI=armeabi-v7a
register_option "--abi=<abi>" select_abi "Select ABI (armeabi, armeabi-v7a, x86)"
select_abi () {
    ABI=$1
}

BOOST_VER1=1
BOOST_VER2=58
BOOST_VER3=0
register_option "--boost=<version>" boost_version "Boost version to be used." \
                "$BOOST_VER1.$BOOST_VER2.$BOOST_VER3"

boost_version()
{
    IFS=. read -r BOOST_VER1 BOOST_VER2 BOOST_VER3 <<<"$1"
}

CXX=arm-linux-androideabi-g++
register_option "--cxx=<cxx-bin>" select_cxx "The name of the cxx executable" \
                "$CXX"

select_cxx() {
    CXX=$1
}

register_option "--toolchain=<toolchain>" select_toolchain "Select a toolchain. To see available execute ls -l ANDROID_NDK/toolchains."

select_toolchain () {
    TOOLCHAIN=$1
}

JOBS=1
register_option "--jobs=<N>" set_jobs "Compile on N threads." "$JOBS"

set_jobs () {
    JOBS=$1
}

CLEAN=no
register_option "--clean"    do_clean     "Delete all previously downloaded and built files, then exit." "$CLEAN"

do_clean () {	CLEAN=yes; }

DOWNLOAD=no

register_option "--download" do_download  "Only download required files and clean up previus build. No build will be performed." "$DOWNLOAD"

do_download ()
{
	DOWNLOAD=yes
	# Clean previus stuff too!
	CLEAN=yes
}

#LIBRARIES=--with-libraries=date_time,filesystem,program_options,regex,signals,system,thread,iostreams,locale
LIBRARIES=
register_option "--with-libraries=<list>" do_with_libraries "Comma separated list of libraries to build."
do_with_libraries () { 
  for lib in $(echo $1 | tr ',' '\n') ; do LIBRARIES="--with-$lib ${LIBRARIES}"; done 
}

register_option "--without-libraries=<list>" do_without_libraries "Comma separated list of libraries to exclude from the build."
do_without_libraries () {	LIBRARIES="--without-libraries=$1"; }
do_without_libraries () { 
  for lib in $(echo $1 | tr ',' '\n') ; do LIBRARIES="--without-$lib ${LIBRARIES}"; done 
}

register_option "--prefix=<path>" do_prefix "Prefix to be used when installing libraries and includes."
do_prefix () {
    if [ -d $1 ]; then
        PREFIX=$1;
    fi
}

PROGRAM_PARAMETERS="<ndk-root>"
PROGRAM_DESCRIPTION=\
"  Boost For Android

  Copyright (C) 2018-current IsCool Entertainment
  Copyright (C) 2010 Mystic Tree Games"\

extract_parameters "$@"

echo "Building boost version: $BOOST_VER1.$BOOST_VER2.$BOOST_VER3"

# -----------------------
# Build constants
# -----------------------

BOOST_DOWNLOAD_LINK="http://downloads.sourceforge.net/project/boost/boost/$BOOST_VER1.$BOOST_VER2.$BOOST_VER3/boost_${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fboost%2Ffiles%2Fboost%2F${BOOST_VER1}.${BOOST_VER2}.${BOOST_VER3}%2F&ts=1291326673&use_mirror=garr"
BOOST_TAR="boost_${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}.tar.bz2"
BOOST_DIR="boost_${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}"
BUILD_DIR="./build-${ABI}/"
BUILD_MARKER=boost-build.done

# -----------------------

if [ $CLEAN = yes ] ; then
	echo "Cleaning: $BUILD_DIR"
	rm -f -r $PROGDIR/$BUILD_DIR
	
	echo "Cleaning: $BOOST_DIR"
	rm -f -r $PROGDIR/$BOOST_DIR
	
	echo "Cleaning: $BOOST_TAR"
	rm -f $PROGDIR/$BOOST_TAR

	echo "Cleaning: logs"
	rm -f -r logs
	rm -f build.log $BUILD_MARKER

  [ "$DOWNLOAD" = "yes" ] || exit 0
fi

AndroidNDKRoot=$PARAMETERS
if [ -z "$AndroidNDKRoot" ] ; then
  if [ -n "${ANDROID_BUILD_TOP}" ]; then # building from Android sources
    AndroidNDKRoot="${ANDROID_BUILD_TOP}/prebuilts/ndk/current"
    export AndroidSourcesDetected=1
  elif [ -z "`which ndk-build`" ]; then
    dump "ERROR: You need to provide a <ndk-root>!"
    exit 1
  else
    AndroidNDKRoot=`which ndk-build`
    AndroidNDKRoot=`dirname $AndroidNDKRoot`
  fi
  echo "Using AndroidNDKRoot = $AndroidNDKRoot"
else
  # User passed the NDK root as a parameter. Make sure the directory
  # exists and make it an absolute path.
  if [ ! -f "$AndroidNDKRoot/ndk-build" ]; then
    dump "ERROR: $AndroidNDKRoot is not a valid NDK root"
    exit 1
  fi
  AndroidNDKRoot=$(cd $AndroidNDKRoot; pwd -P)
fi
export AndroidNDKRoot
export CXX
export MARCH

# Check platform patch
case "$HOST_OS" in
    linux)
        PlatformOS=linux
        ;;
    darwin|freebsd)
        PlatformOS=darwin
        ;;
    windows|cygwin)
        PlatformOS=windows
        ;;
    *)  # let's play safe here
        PlatformOS=linux
esac

NDK_RELEASE_FILE=$AndroidNDKRoot"/RELEASE.TXT"
if [ -f "${NDK_RELEASE_FILE}" ]; then
    NDK_RN=`cat $NDK_RELEASE_FILE | sed 's/^r\(.*\)$/\1/g'`
elif [ -n "${AndroidSourcesDetected}" ]; then
    if [ -f "${ANDROID_BUILD_TOP}/ndk/docs/CHANGES.html" ]; then
        NDK_RELEASE_FILE="${ANDROID_BUILD_TOP}/ndk/docs/CHANGES.html"
        NDK_RN=`grep "android-ndk-" "${NDK_RELEASE_FILE}" | head -1 | sed 's/^.*r\(.*\)$/\1/'`
    elif [ -f "${ANDROID_BUILD_TOP}/ndk/docs/text/CHANGES.text" ]; then
        NDK_RELEASE_FILE="${ANDROID_BUILD_TOP}/ndk/docs/text/CHANGES.text"
        NDK_RN=`grep "android-ndk-" "${NDK_RELEASE_FILE}" | head -1 | sed 's/^.*r\(.*\)$/\1/'`
    else
        dump "ERROR: can not find ndk version"
        exit 1
    fi
else
    dump "ERROR: can not find ndk version"
    exit 1
fi

echo "Detected Android NDK version $NDK_RN"

case "$NDK_RN" in
	"10e (64-bit)"|"10e-rc4 (64-bit)")
		TOOLCHAIN=${TOOLCHAIN:-arm-linux-androideabi-4.9}
		CXXPATH=$AndroidNDKRoot/toolchains/${TOOLCHAIN}/prebuilt/${PlatformOS}-x86_64/bin/${CXX}
		TOOLSET=gcc-androidR10e
		;;
	*)
		echo "Undefined or not supported Android NDK version!"
		exit 1
esac

if [ -n "${AndroidSourcesDetected}" ]; then # Overwrite CXXPATH if we are building from Android sources
    CXXPATH="${ANDROID_TOOLCHAIN}/${CXX}"
fi

echo Building with TOOLSET=$TOOLSET CXXPATH=$CXXPATH CXXFLAGS=$CXXFLAGS | tee $PROGDIR/build.log

# Check if the ndk is valid or not
if [ ! -f $CXXPATH ]
then
	echo "Cannot find C++ compiler at: $CXXPATH"
	exit 1
fi

# -----------------------
# Download required files
# -----------------------

# Downalod and unzip boost in a temporal folder and
if [ ! -f $BOOST_TAR ]
then
	echo "Downloading boost ${BOOST_VER1}.${BOOST_VER2}.${BOOST_VER3} please wait..."
	prepare_download
	download_file $BOOST_DOWNLOAD_LINK $PROGDIR/$BOOST_TAR

        if [ -d "$PROGDIR/$BOOST_DIR" ]; then
	    echo "Cleaning: $BOOST_DIR"
	    rm -f -r $PROGDIR/$BOOST_DIR
        fi
fi

if [ ! -f $PROGDIR/$BOOST_TAR ]
then
	echo "Failed to download boost! Please download boost ${BOOST_VER1}.${BOOST_VER2}.${BOOST_VER3} manually\nand save it in this directory as $BOOST_TAR"
	exit 1
fi

if [ ! -d $PROGDIR/$BOOST_DIR ]
then
	echo "Unpacking boost"
	if [ "$OPTION_PROGRESS" = "yes" ] ; then
		pv $PROGDIR/$BOOST_TAR | tar xjf - -C $PROGDIR
	else
		tar xjf $PROGDIR/$BOOST_TAR
	fi
fi

if [ $DOWNLOAD = yes ] ; then
	echo "All required files has been downloaded and unpacked!"
	exit 0
fi

# ---------
# Bootstrap
# ---------
if [ ! -f ./$BOOST_DIR/bjam ]
then
  # Make the initial bootstrap
  echo "Performing boost bootstrap"

  cd $BOOST_DIR 
  case "$HOST_OS" in
    windows)
        cmd //c "bootstrap.bat" 2>&1 | tee -a $PROGDIR/build.log
        ;;
    *)  # Linux and others
        ./bootstrap.sh 2>&1 | tee -a $PROGDIR/build.log
    esac


  if [ $? != 0 ] ; then
  	dump "ERROR: Could not perform boostrap! See $TMPLOG for more info."
  	exit 1
  fi
  cd $PROGDIR
  
  # -------------------------------------------------------------
  # Patching will be done only if we had a successfull bootstrap!
  # -------------------------------------------------------------

  # Apply patches to boost
  BOOST_VER=${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}
  PATCH_BOOST_DIR=$(cd $(dirname $0); pwd)/patches/boost-${BOOST_VER}

  cp `dirname $0`/configs/user-config-boost-${BOOST_VER}-${ABI}.jam $BOOST_DIR/tools/build/src/user-config.jam

  if [ -d "$PATCH_BOOST_DIR" ]
  then
      PATCHES=`(cd $PATCH_BOOST_DIR && ls *.patch | sort) 2> /dev/null`

      if [ -z "$PATCHES" ]; then
          echo "No patches found in directory '$PATCH_BOOST_DIR'"
          exit 1
      fi

      for PATCH in $PATCHES; do
          PATCH=`echo $PATCH | sed -e s%^\./%%g`
          SRC_DIR=$PROGDIR/$BOOST_DIR
          PATCHDIR=`dirname $PATCH`
          PATCHNAME=`basename $PATCH`
          log "Applying $PATCHNAME into $SRC_DIR/$PATCHDIR"
          cd $SRC_DIR && (pwd; patch -p1 < $PATCH_BOOST_DIR/$PATCH ) && cd $PROGDIR
          if [ $? != 0 ] ; then
              dump "ERROR: Patch failure !! Please check your patches directory!"
              dump "       Try to perform a clean build using --clean ."
              dump "       Problem patch: $dir/$PATCHNAME"
              exit 1
          fi
      done
  fi
fi

echo "# ---------------"
echo "# Build using NDK"
echo "# ---------------"

if [ -f $BUILD_MARKER ]
then
    echo "$BUILD_MARKER exists. Skipping."
else
    # Build boost for android
    echo "Building boost for android"
    (

        if echo $LIBRARIES | grep locale; then
            if [ -e libiconv-libicu-android ]; then
                echo "ICONV and ICU already compiled"
            else
                echo "boost_locale selected - compiling ICONV and ICU"
                git clone https://github.com/pelya/libiconv-libicu-android.git
                cd libiconv-libicu-android
                ./build.sh || exit 1
                cd ..
            fi
        fi

        cd $BOOST_DIR

        echo "Adding pathname: `dirname $CXXPATH`"
        # `AndroidBinariesPath` could be used by user-config-boost-*.jam
        export AndroidBinariesPath=`dirname $CXXPATH`
        export PATH=$AndroidBinariesPath:$PATH
        export AndroidNDKRoot
        export AndroidToolchainVersion=$(echo "$TOOLCHAIN" | sed 's/.*-\([^-]*\)/\1/')
        export AndroidTargetVersion=21
        export NO_BZIP2=1

        cxxflags=""
        for flag in $CXXFLAGS; do cxxflags="$cxxflags cxxflags=$flag"; done

        { ./bjam -q                         \
                 target-os=linux              \
                 toolset=$TOOLSET             \
                 $cxxflags                    \
                 link=static                  \
                 threading=multi              \
                 --layout=system              \
                 -sICONV_PATH=`pwd`/../libiconv-libicu-android/armeabi \
                 -sICU_PATH=`pwd`/../libiconv-libicu-android/armeabi \
                 --prefix="./../$BUILD_DIR/"  \
                 $LIBRARIES                   \
                 --debug-configuration \
                 -j$JOBS                      \
                 install 2>&1                 \
              || { dump "ERROR: Failed to build boost for android!" ; exit 1 ; }
        } | tee -a $PROGDIR/build.log
    )

    dump "Done!"

    if [ $PREFIX ]; then
        echo "Prefix set, copying files to $PREFIX"
        cp -r $PROGDIR/$BUILD_DIR/lib $PREFIX
        cp -r $PROGDIR/$BUILD_DIR/include $PREFIX
    fi

    touch $BUILD_MARKER
fi
