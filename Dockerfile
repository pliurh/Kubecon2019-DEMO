FROM centos:centos7.7.1908
ARG MOFED_VER=4.7-1.0.0.1
ENV MOFED_VER $MOFED_VER
ENV OS_VER rhel7.7
ENV PLATFORM x86_64
RUN yum install -y perl numactl-libs gtk2 atk cairo gcc-gfortran tcsh libnl3 tcl tk python-devel \
    pciutils make lsof redhat-rpm-config rpm-build libxml2-python ethtool \
    iproute net-tools openssh-clients git openssh-server wget
WORKDIR /tmp/
RUN wget http://content.mellanox.com/ofed/MLNX_OFED-${MOFED_VER}/MLNX_OFED_LINUX-${MOFED_VER}-${OS_VER}-${PLATFORM}.tgz && \
    tar -xf MLNX_OFED_LINUX-${MOFED_VER}-${OS_VER}-${PLATFORM}.tgz && \
    MLNX_OFED_LINUX-${MOFED_VER}-${OS_VER}-${PLATFORM}/mlnxofedinstall --user-space-only --without-fw-update --all --force \
    && rm -rf /tmp/

# Install prerequisite packages
RUN rpm --import https://mirror.go-repo.io/centos/RPM-GPG-KEY-GO-REPO && curl -s https://mirror.go-repo.io/centos/go-repo.repo | tee /etc/yum.repos.d/go-repo.repo
RUN yum groupinstall -y "Development Tools"
RUN yum install -y wget numactl-devel git golang make libibverbs-devel && yum clean all
# Download and compile DPDK
ENV DPDK_VER 19.08
ENV DPDK_DIR /usr/src/dpdk-${DPDK_VER}
WORKDIR /usr/src/
RUN wget http://fast.dpdk.org/rel/dpdk-${DPDK_VER}.tar.xz
RUN tar -xpvf dpdk-${DPDK_VER}.tar.xz

ENV RTE_TARGET=x86_64-native-linuxapp-gcc
ENV RTE_SDK=${DPDK_DIR}
WORKDIR ${DPDK_DIR}

RUN sed -i -e 's/EAL_IGB_UIO=y/EAL_IGB_UIO=n/' config/common_linux
RUN sed -i -e 's/KNI_KMOD=y/KNI_KMOD=n/' config/common_linux
RUN sed -i -e 's/LIBRTE_KNI=y/LIBRTE_KNI=n/' config/common_linux
RUN sed -i -e 's/LIBRTE_PMD_KNI=y/LIBRTE_PMD_KNI=n/' config/common_linux
RUN sed -i 's/\(CONFIG_RTE_LIBRTE_MLX5_PMD=\)n/\1y/g' $DPDK_DIR/config/common_base
RUN make install T=${RTE_TARGET} DESTDIR=${RTE_SDK}
#
# Build TestPmd
#
WORKDIR ${DPDK_DIR}/app/test-pmd
RUN make
RUN cp testpmd /usr/bin/testpmd
