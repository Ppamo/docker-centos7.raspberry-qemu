FROM centos:centos7
MAINTAINER "Ppamo" <pablo@ppamo.cl>

# Enable EPEL Repo
COPY epel/epel.repo /etc/yum.repos.d/
COPY epel/RPM-GPG-KEY-EPEL-7 /etc/pki/rpm-gpg/

# update system and install qemu for arm
RUN yum -y --setopt=tsflags=nodocs update && \
	yum -y install qemu-system-arm net-tools bridge-utils && \
	yum clean all

EXPOSE 22
