### Docker Raspberry emulator, based on centos 7 and qemu

This docker file is based on centos 7 and uses qemu to load a raspberry kernel and image.

#### Usage
bash setup.sh *KERNEL_PATH* *IMAGE_PATH* *[MEMORY]*
* *KERNEL_PATH*: full path to the kernel to load.
* *IMAGE_PATH*: full path to the image to load.
* *MEMORY*: number in megabytes to assign as memory to the emulated machine.   __Some machine failed to boot, assigning more than 256 of memory.__

After execute the script you can access the container's logs to check if the image have complete the boot process and is ready to accept ssh connections through the container's mapped 22 port, or directally from the container's IP.

#### setup.sh
This is mostly a Docker wrap.   It start checking if the docker service is running and Dockerfile exists.   Then check if the docker image exists if not, it build it.

Finally start a container in background and privileged mode, passing the *KERNEL*, *IMAGE* and *MEMORY* values to the container and mounting kernel and image path's as volumes.

#### Dockerfile
At start enables the EPEL repo, in order to install the qemu-system-arm package.   Then update the packages and install qemu-system-arm net-tools bridge-utils.

Then copy the run.sh script to /opt and qemu-ifup.sh to /etc.
Finally exposes the 22 port and set the init command to run the "run.sh" script.

#### run.sh
The script uses 3 environment variables to start the emulator:
* KERNEL: Required, describes the path in the container, to the kernel file.
* IMAGE: Required, describes the path in the container, to the image file.
* MEMORY: Optional, the megabytes of memory asignated to the emulated machine, the default value is __256__.   ***Some images fails to boot on machines with more than 256M***

Before boot the image it should be prepared, so the script search for the Linux and FAT32 partitions, the first one is the boot partition and in order to enable ssh service the file /ssh is touched in the boot partition.

In the next partition, udev qemu's rules are created writing in the file */etc/udev/rules.d/90-qemu.rules*.   After that the file /etc/rc.local is replaced to a new script that setup the network in the raspberry image at boot. Basically it assign the container's ip to the emulated machine, (which was removed from the container in the at qemu start, see qemu-ifup.sh script for details).

Some qemu versions have issues booting, so the lines in the file */etc/ld.so.preload* get commented in order to boot the image.

Finally it run **qemu-system-arm** using the KERNEL, IMAGE and MEMORY values, and the start script /etc/qemu-ifup.sh.

#### qemu.sh
This script is executed in the container when qemu is launched and it basically configure the network.

The container's IP is removed to be assigned later to the emulated machine, then a tap device is created and a bridge.   The bridge joins the container's eth0 interface and the emulated machine's tap device.

This setup allow to the host machine to access to the emulated interface through the container exposed port, or directally from the assigned IP address.
