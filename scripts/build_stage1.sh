#!/bin/bash
set -e

git clone https://github.com/r58Playz/buildroot -b terra-stage1
cd buildroot
make ${1}_defconfig 
make
cp output/images/rootfs.tar ../terra-stage1.tar
