#!/bin/sh

WORKSPACE=/home/live/opr
OPR_DIR=/usr/local/openresty
OPR_VER=1.11.2.3

rm -rf ${WORKSPACE}
mkdir -p ${WORKSPACE}
sudo rm -rf ${OPR_DIR}
sudo mkdir -p ${OPR_DIR}
cd ${WORKSPACE}

sudo apt-get update
sudo apt-get install -V libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl make cmake build-essential
wget https://openresty.org/download/openresty-${OPR_VER}.tar.gz
tar -xf openresty-${OPR_VER}.tar.gz

cd openresty-${OPR_VER}
./configure --prefix=${OPR_DIR} --with-http_stub_status_module
make
sudo make install
