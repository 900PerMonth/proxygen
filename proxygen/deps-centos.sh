#!/bin/bash

## Run this script to build proxygen and run the tests. If you want to
## install proxygen to use in another C++ project on this machine, run
## the sibling file `reinstall.sh`.

# Parse args
JOBS=8
USAGE="./deps.sh [-j num_jobs]"
while [ "$1" != "" ]; do
  case $1 in
    -j | --jobs ) shift
                  JOBS=$1
                  ;;
    * )           echo $USAGE
                  exit 1
esac
shift
done

set -e
start_dir=`pwd`
trap "cd $start_dir" EXIT

folly_rev=$(sed 's/Subproject commit //' "$start_dir"/../build/deps/github_hashes/facebook/folly-rev.txt)
wangle_rev=$(sed 's/Subproject commit //' "$start_dir"/../build/deps/github_hashes/facebook/wangle-rev.txt)

# Must execute from the directory containing this script
cd "$(dirname "$0")"

# RedHet/CentOS

sudo yum -y install autoconf automake libtool cmake autoconf-archive gcc-c++ boost-devel
sudo yum -y install devtoolset-7-gcc-c++ devtoolset-7-binutils-devel
export CXX=/opt/rh/devtoolset-7/root/usr/bin/g++

if [ ! -e google-glog ]; then
    echo "fetching glog from github.com"
    git clone https://github.com/google/glog.git google-glog
    cd google-glog
    ./autogen.sh
    ./configure
    make
    sudo make install
    cd ..
fi

if [ ! -e gflags-gflags ]; then
    echo "fetching gflags from github.com"
    git clone https://github.com/gflags/gflags gflags-gflags
    cd gflags-gflags
    ccmake3 . -DBUILD_SHARED_LIBS=ON # emacs embeded shell does not function well
    make
    sudo make install
    cd ..
fi

if [ ! -e double-conversion ]; then
    echo "Fetching double-conversion from git..."
    git clone https://github.com/floitsch/double-conversion.git double-conversion
    cd double-conversion
    cmake3 . -DBUILD_SHARED_LIBS=ON
    sudo make install
    cd ..
fi


# Get folly
if [ ! -e folly/folly ]; then
    echo "Cloning folly"
    git clone https://github.com/facebook/folly
fi
cd folly/folly
git fetch
git checkout "$folly_rev"

# Build folly
cd ..
if [ ! -e build ]; then
    mkdir build
fi
cd build
cmake3 -DBUILD_SHARED_LIBS=ON -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF ..
make -j$JOBS
sudo make install

if test $? -ne 0; then
  echo "fatal: folly build failed"
  exit -1
fi
cd ../..

# Get fizz
if [ ! -e fizz ]; then
    echo "Fetching fizz from git..."
    git clone https://github.com/facebookincubator/fizz.git
fi

# Build fizz
cd fizz
git checkout v2018.10.15.00

if [ ! -e build_ ]; then
    mkdir build_
fi
cd build_
cmake3 -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF ../fizz
make -j$JOBS
sudo make install

if test $? -ne 0; then
  echo "fatal: fizz build failed"
  exit -1
fi
cd ../..

# Get wangle
if [ ! -e wangle/wangle ]; then
    echo "Cloning wangle"
    git clone https://github.com/facebook/wangle
fi
cd wangle/wangle
git fetch
git checkout "$wangle_rev"

# Build wangle
cmake3 .
make -j$JOBS
sudo make install

if test $? -ne 0; then
  echo "fatal: wangle build failed"
  exit -1
fi
cd ../..

# Build proxygen
autoreconf -ivf
./configure
make -j$JOBS

# Run tests
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH make check

# Install the libs
sudo make install
