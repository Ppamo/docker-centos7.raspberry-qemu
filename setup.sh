#!/bin/bash
IMAGENAME=centos7-qemu
IMAGETAG=latest
IMAGEVERSION=v0.1
GRAPHICS='-e DISPLAY=:0 -v /tmp/.X11-unix:/tmp/.X11-unix -e GRAPHICSOPTIONS='
CMD='/opt/scripts/run.sh'

# Parse kernel and image path
if [ -f "$1" -a -f "$2" ]; then
	KERNELFILE=$(basename $1)
	KERNELPATH=$(dirname $1)
	KERNEL=/opt/raspberry/kernels/$KERNELFILE
	IMAGEFILE=$(basename $2)
	IMAGEPATH=$(dirname $2)
	IMAGE=/opt/raspberry/images/$IMAGEFILE
else
	echo "IMAGE or KERNEL file not found"
	exit -1
fi

# check memory value
if [ -n "$3" ]; then MEMORY="-e MEMORY=$3"; fi
# check graph mode
if [ -n "$4" ]; then
	GRAPHICS="-e GRAPHICSOPTIONS=$4"
fi
# check command
if [ -n "$5" ]; then CMD="$5"; fi


# check if docker is running
docker info > /dev/null 2>&1
if [ $? -ne 0 ]
then
	echo "Cannot connect to the Docker daemon. Is the docker daemon running on this host?"
	exit -1
fi

# check if the Dockerfile is in the folder
if [ ! -f Dockerfile ]
then
	echo "Dockerfile is not present, please run the script from right folder"
	exit -1
fi

# check if the docker image exists
docker images | grep "$IMAGENAME" | grep "$IMAGETAG" > /dev/null 2>&1
if [ $? -ne 0 ]
then
	# create the docker image
	docker build -t $IMAGENAME:$IMAGEVERSION -t $IMAGENAME:$IMAGETAG ./
	if [ $? -ne 0 ]
	then
		echo "docker build failed!"
		exit -1
	fi
fi

# selinux permissions to the shared volumes
if [ -d $KERNELPATH ]; then
	chcon -Rt svirt_sandbox_file_t $KERNELPATH
fi
if [ -d $IMAGEPATH ]; then
	chcon -Rt svirt_sandbox_file_t $IMAGEPATH
fi
chcon -Rt svirt_sandbox_file_t scripts

# run a container from $IMAGENAME image
docker run --privileged=true -di -P -v $PWD/scripts:/opt/scripts -v $KERNELPATH:/opt/raspberry/kernels -v $IMAGEPATH:/opt/raspberry/images -e "KERNEL=$KERNEL" -e "IMAGE=$IMAGE" $MEMORY $GRAPHICS "$IMAGENAME:$IMAGETAG" $CMD
