## Docker Raspberry emulator

This docker file is based on centos 7 and uses qemu to load a raspberry kernel and image.

In order to run the container you will need a ARM1176 kernel for qemu, and you can create one following [this guide](https://web.archive.org/web/20131210001638/http://xecdesign.com/compiling-a-kernel/) or just download one.


Also need a raspberry image.


### Usage
bash setup.sh *KERNEL_PATH* *IMAGE_PATH* *[MEMORY]* *[GRAPHICS OPTIONS]* *[COMMAND]*
* *KERNEL_PATH*: full path to the kernel to load.
* *IMAGE_PATH*: full path to the image to load.
* *MEMORY*: number in megabytes to assign as memory to the emulated machine.   __Note: some machines failed to boot,  when more than 256M of memory were assigned.__
* *GRAPHICS OPTIONS*: Graphical options to be sent directly to qemu. ie "-nographic"
* *COMMAND*: Command to be executed by the Container, by default is "/bin/bash scripts/run.sh", but can be set to __/bin/bash__ to debug the scripts.

After execute the script you can access the container's logs to check if the image have complete the boot process and is ready to accept ssh connections through the container's mapped 22 port, or directally from the container's IP.

### Output

When execute the script for the first time, it will start to build the docker image:

```bash
[develop]# ./setup.sh \
    images/kernel-qemu-4.4.34-jessie \
    images/2017-06-21-raspbian-jessie-lite.img \
    150

Sending build context to Docker daemon 91.65 kB
Step 1 : FROM centos:centos7
 ---> 02d7bb721769
Step 2 : MAINTAINER "Ppamo" <pablo@ppamo.cl>
 ---> Using cache
 ---> a6f736158a12
Step 3 : COPY epel/epel.repo /etc/yum.repos.d/
 ---> 920263d39904
Removing intermediate container d3e0a0ed059e
Step 4 : COPY epel/RPM-GPG-KEY-EPEL-7 /etc/pki/rpm-gpg/
 ---> dd68dd890d0a
Removing intermediate container 503488222b25
Step 5 : RUN yum -y --setopt=tsflags=nodocs update &&   yum -y install qemu-system-arm net-tools bridge-utils &&  y
um clean all
 ---> Running in bcf9f35610dd

...

Complete!
Loaded plugins: fastestmirror, ovl
Cleaning repos: base epel extras updates
Cleaning up everything
Cleaning up list of fastest mirrors
 ---> 8f19f1dd695a
Removing intermediate container bcf9f35610dd
Step 6 : COPY run.sh /opt/
 ---> 4ccc812ea2e3
Removing intermediate container 5270a9068278
Step 7 : COPY qemu-ifup.sh /etc/
 ---> b41a6cac5b76
Removing intermediate container 56b55970f491
Step 8 : RUN chmod 750 /etc/qemu-ifup.sh &&     chown root:kvm /etc/qemu-ifup.sh
 ---> Running in 2945d011a18e
 ---> 475967f60692
Removing intermediate container 2945d011a18e
Step 9 : EXPOSE 22
 ---> Running in 49f8e965350a
 ---> cf2ff7a9bb4c
Removing intermediate container 49f8e965350a
Step 10 : CMD /bin/bash /opt/run.sh
 ---> Running in 94a401f83b2e
 ---> f6bd008ac246
Removing intermediate container 94a401f83b2e
Successfully built f6bd008ac246
574ac443702f3924e28fd711222fbc760f08d7b3afbae84230a8a85c24da6b3b
```

The next time you execute the script the image will be available so it will skip the build and run container directly.

At this point you can attach to the docker log's to see if everything goes ok:

```bash
[develop]# docker ps
CONTAINER ID        IMAGE                 COMMAND                 CREATED             STATUS              PORTS                NAMES
574ac443702f        centos7-qemu:latest   "/bin/bash /opt/run.s"  6 seconds ago       Up 3 seconds        0.0.0.0:32788->22/tcp   sleepy_leavitt
[develop]# docker logs -f 574ac443702f
Using default memory value (256)
using ip=172.17.0.2 gateway=172.17.0.1

...

Uncompressing Linux... done, booting the kernel.
Booting Linux on physical CPU 0x0
Initializing cgroup subsys cpuset

...

[  OK  ] Started /etc/rc.local Compatibility.
[  OK  ] Started LSB: Start NTP daemon.
[  OK  ] Started Permit User Sessions.
         Starting OpenBSD Secure Shell server...
[  OK  ] Started OpenBSD Secure Shell server.
         Starting Hold until boot process finishes up...
         Starting Terminate Plymouth Boot Screen...
[  OK  ] Started Turn on SSH if /boot/ssh is present.

Raspbian GNU/Linux 8 raspberrypi ttyAMA0
```

When you see this welcome message the image is ready to accept ssh connections:

```bash
[develop]# docker ps
CONTAINER ID        IMAGE                 COMMAND                 CREATED              STATUS              PORTS                 NAMES
574ac443702f        centos7-qemu:latest   "/bin/bash /opt/run.s"  About a minute ago   Up About a minute   0.0.0.0:**32788**->22/tcp  sleepy_leavitt
[root@escher docker-centos7.raspberry-qemu]# ssh pi@localhost -p 32788
pi@localhost's password:
```

### Code

#### setup.sh
This script is mostly a Docker wrapper, It check the docker service and the Dockerfile.   Then check if the docker image exists if not, it build it.

Finally run a container in background and privileged mode, passing the *KERNEL*, *IMAGE* and *MEMORY* values to the container and mounting kernel and image path as volumes.

#### Dockerfile
At start it enables the EPEL repo, in order to install the qemu-system-arm package.   Then updates system packages and install qemu-system-arm, net-tools and bridge-utils.

Then it copy the run.sh script to /opt and qemu-ifup.sh to /etc.
Finally exposes the 22 port and set the init command to run the "run.sh" script.

#### run.sh
The script uses this environment variables to start the emulator:
* KERNEL: Required, describes the path in the container, to the kernel file.
* IMAGE: Required, describes the path in the container, to the image file.
* MEMORY: Optional, the megabytes of memory assigned to the emulated machine, the default value is __256__.   ***Note: some test images failed to boot on machines with more than 256M***
* GRAPHICSOPTIONS: Graphical options to be sent to qemu, default value is:
```-e DISPLAY=:0 -v /tmp/.X11-unix:/tmp/.X11-unix -e GRAPHICSOPTIONS=```
this allow qemu to connect to host's display.   It can be set to "-nographic" to disable qemu's graphical mode.

Before boot the image it should be setted up, so the script searchs for the Linux and FAT32 partitions.

The first one is the boot partition and in order to enable ssh service the file /ssh is 'touched'.

In the next partition, udev qemu's rules are created writing in the file */etc/udev/rules.d/90-qemu.rules*.   After that the file /etc/rc.local is replaced to a new script that setup the network in the raspberry image at boot.

Basically it add the container's ip to the emulated net device, (which was removed from the container in the at qemu start, see qemu-ifup.sh script for details).

Some qemu versions have issues booting, so the lines in the file */etc/ld.so.preload* get commented in order to boot the image.

Finally it run **qemu-system-arm** using the KERNEL, IMAGE and MEMORY values, and the start script /etc/qemu-ifup.sh.

#### qemu-ifup.sh
This script is executed in the container when qemu is launched and it basically configure the network.

The container's IP is removed to be assigned later to the emulated machine, then a tap device is created and a bridge.   The bridge joins the container's eth0 interface and the emulated machine's tap device.

This setup allow to the host machine to access to the emulated interface through the container exposed port, or directly from the assigned IP address.
