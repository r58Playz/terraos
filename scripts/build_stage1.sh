#!/bin/bash
set -e

if [ $# -lt 1 ]; then
  echo "usage: build_stage1.sh <defconfig>"
  echo "available defconfigs:"
  echo " - terraos"
  echo " - terraos_jacuzzi"
  exit 1
fi

git clone https://github.com/r58Playz/buildroot -b terra-stage1
cd buildroot
make ${1}_defconfig 
make
cp output/images/rootfs.tar ../terra-stage1.tar
