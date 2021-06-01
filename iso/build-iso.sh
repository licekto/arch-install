#!/bin/bash

TMP_DIR="/tmp/archiso"
ISO_DIR="$TMP_DIR/archlive"
WORKD_DIR="$TMP_DIR/workdir"
INSTALL_DIR="$ISO_DIR/airootfs/install"
OUT_DIR=$(pwd)
KEY_PATH="/home/tomas"

if [[ $# -eq 1 ]];
then
	OUT_DIR="$1"
fi

prepare_dirs()
{
	echo "Copying files to $ISO_DIR..."
	mkdir -p $ISO_DIR
	cp -r /usr/share/archiso/configs/releng/* $ISO_DIR
	
	mkdir -p $WORKD_DIR
	mkdir -p $INSTALL_DIR
	mkdir $INSTALL_DIR/configs
	
	# Will not copy .git files and any other hidden files
	cp -r ../install/configs/* $INSTALL_DIR/configs
	cp ../install/bootstrap.sh $INSTALL_DIR
	cp ../install/install.cfg $INSTALL_DIR
	cp ../install/install.sh $INSTALL_DIR
	cp ../install/pkglist.txt $INSTALL_DIR
	cp ../install/postinstall.sh $INSTALL_DIR
}

get_key()
{
	echo "Copying private key to the image to access github repositories..."
	PUB_KEY=$(ls $KEY_PATH/.ssh/*.pub)
	PRIV_KEY=${PUB_KEY%.pub}
	mkdir $INSTALL_DIR/key
	cp $PUB_KEY $INSTALL_DIR/key
	cp $PRIV_KEY $INSTALL_DIR/key
}

build_iso()
{
	echo "Building the installation image, it may take a few minutes..."
	sudo time mkarchiso -v -w $WORKD_DIR -o $OUT_DIR $ISO_DIR > mkarchiso.log 2>&1
}

clean()
{
	echo "Cleaning up the working directories in $TMP_DIR..."
	sudo rm -rf $TMP_DIR
}

prepare_dirs
get_key
build_iso
clean
