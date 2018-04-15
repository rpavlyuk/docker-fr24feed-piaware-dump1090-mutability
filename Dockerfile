FROM centos:7
MAINTAINER "Roman Pavlyuk" <roman.pavlyuk@gmail.com>

ENV container docker

RUN yum install -y epel-release

RUN yum update -y

RUN yum install -y \
	less \
	file \
	mc \
	vim-enhanced \
	telnet \
	net-tools \
	which \
	bash-completion \
	openssh-clients \
	libusb-devel \
	libusbx-devel \
	cmake \
	wget \
	git \
	pkgconfig \
	gcc \
	make \
	glibc \
	autoconf \
	automake \
	filesystem \
	libtool

### Let's enable systemd on the container
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;
VOLUME [ "/sys/fs/cgroup" ]


# Install GCC 7
WORKDIR /tmp
RUN wget https://ftp.gnu.org/gnu/gcc/gcc-7.3.0/gcc-7.3.0.tar.gz && \
        tar xfz gcc-7.3.0.tar.gz
RUN yum install -y \
	libmpc-devel \
	mpfr-devel \
	gmp-devel \
	gcc-c++ \
	gcc-c++-devel \
	zlib-devel \
	zlib
RUN cd gcc-7.3.0 && \
	./configure --with-system-zlib --disable-multilib --enable-languages=c,c++ && \
	make -j 8 && \
	make install && \
	rm -rf /tmp/gcc-7.3.0	

# Update GLIBC
RUN yum groupinstall -y "Development tools"
RUN yum install -y \
	glibc-devel.i686 \
	glibc-i686
WORKDIR /tmp
RUN wget https://ftp.gnu.org/gnu/glibc/glibc-2.19.tar.gz && \
	tar -xvzf glibc-2.19.tar.gz
RUN cd glibc-2.19 && \
	mkdir glibc-build && \
	cd glibc-build && \
	../configure --prefix='/usr' && \
	make && \
	make install && \
	rm -rf /tmp/glibc-2.19

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig/:${PKG_CONFIG_PATH}"

COPY local-lib64.conf /etc/ld.so.conf.d/local-lib64.conf
COPY local-lib.conf /etc/ld.so.conf.d/local-lib.conf
RUN ldconfig 

RUN gcc --version
RUN ldd --version


# install RTL-SDR driver
WORKDIR /tmp
RUN echo 'blacklist dvb_usb_rtl28xxu' > /etc/modprobe.d/raspi-blacklist.conf && \
    git clone git://git.osmocom.org/rtl-sdr.git && \
    cd rtl-sdr/ && \
    autoreconf -i && \
    ./configure --enable-driver-detach && \
    make && \
    make install && \
    make install-udev-rules && \
    ldconfig && \
    rm -rf /tmp/rtl-sdr

# Some info for debug
RUN cat /usr/local/lib/pkgconfig/librtlsdr.pc
RUN pkg-config --libs librtlsdr libusb-1.0

# DUMP1090
WORKDIR /tmp
RUN git clone https://github.com/mutability/dump1090 && \
    cd dump1090 && \
    make && mkdir /usr/lib/fr24 && cp dump1090 /usr/lib/fr24/ && cp -r public_html /usr/lib/fr24/
COPY config.js /usr/lib/fr24/public_html/
RUN mkdir /usr/lib/fr24/public_html/data

# Uncomment if you want to add your upintheair.json file
#COPY upintheair.json /usr/lib/fr24/public_html/


# PIAWARE
COPY srpms/ /srpms/
RUN rpm --import http://wiki.psychotic.ninja/RPM-GPG-KEY-psychotic
RUN rpm -ivh http://packages.psychotic.ninja/6/base/i386/RPMS/psychotic-release-1.0.0-1.el6.psychotic.noarch.rpm
RUN perl -pi -e "s/enabled\=0/enabled\=1/gi" /etc/yum.repos.d/psychotic.repo
WORKDIR /tmp
RUN yum install -y --enablerepo=psychotic --exclude=tcl-8.5* \
	tcl-devel \
	libX11-devel \
	libXft-devel
# Build TK
RUN rpmbuild --define "debug_package %{nil}" --rebuild /srpms/tk-8.6.5-1.fc24.src.rpm
RUN yum localinstall -y --enablerepo=psychotic --exclude=tcl-8.5* \
        /root/rpmbuild/RPMS/x86_64/tk-*
# Build TCLx
RUN rpmbuild --define "debug_package %{nil}" --rebuild /srpms/tclx-8.4.0-24.fc21.src.rpm
RUN yum localinstall -y --enablerepo=psychotic --exclude=tcl-8.5* \
        /root/rpmbuild/RPMS/x86_64/tclx-*
RUN rpmbuild --define "debug_package %{nil}" --rebuild /srpms/tcllauncher-1.6-3.fc25.src.rpm
RUN yum localinstall -y --enablerepo=psychotic --exclude=tcl-8.5* \
	/root/rpmbuild/RPMS/x86_64/tcllauncher*

# Build and install dependencies
RUN yum install -y openssl-devel && \
	rpmbuild --define "debug_package %{nil}" --rebuild /srpms/tcltls-1.6.7-1.fc22.src.rpm && \
	yum localinstall -y --enablerepo=psychotic --exclude=tcl-8.5* /root/rpmbuild/RPMS/x86_64/tcltls*
RUN rpmbuild --define "debug_package %{nil}" --rebuild /srpms/itcl-4.0.3-2.fc22.src.rpm && \
	yum localinstall -y --enablerepo=psychotic --exclude=tcl-8.5* /root/rpmbuild/RPMS/x86_64/itcl*
RUN rpmbuild --define "debug_package %{nil}" --rebuild /srpms/tcllib-1.17-1.fc22.src.rpm && \
        yum localinstall -y --enablerepo=psychotic --exclude=tcl-8.5* /root/rpmbuild/RPMS/noarch/tcllib*

RUN rm -rf /srpms

# Installing PiAware
RUN mkdir -p /tmp/piaware_install/venv
WORKDIR /tmp/piaware_install


### Dump1090 for PiAware
RUN git clone https://github.com/flightaware/dump1090.git dump1090 && \
        cd dump1090 && \
        git checkout -q --detach v3.5.3 -- && \
        git --no-pager log -1 --oneline
WORKDIR /tmp/piaware_install
RUN make -C dump1090 RTLSDR=no BLADERF=no DUMP1090_VERSION="piaware-3.5.3" faup1090 && \
	/usr/bin/install -d /usr/lib/piaware/helpers && \
	/usr/bin/install -t /usr/lib/piaware/helpers dump1090/faup1090

# Python for MLAT
WORKDIR /tmp/piaware_install
RUN yum install -y \
	python34 \
	python34-setuptools \
	python34-devel \
	python34-pip
RUN /usr/bin/pyvenv /tmp/piaware_install/venv --without-pip
### mlat
RUN git clone https://github.com/mutability/mlat-client.git mlat-client && \
	cd mlat-client && \
	git checkout -q --detach v0.2.10 -- && \
	git --no-pager log -1 --oneline
WORKDIR /tmp/piaware_install
RUN cd mlat-client && \
	/tmp/piaware_install/venv/bin/python setup.py install
### cx_Freeze
WORKDIR /tmp/piaware_install
RUN wget -nv -O - 'https://pypi.python.org/packages/source/c/cx_Freeze/cx_Freeze-4.3.4.tar.gz#md5=5bd662af9aa36e5432e9144da51c6378' | tar -C /tmp/piaware_install -zxf -
RUN cd cx_Freeze-4.3.4 && \
	/tmp/piaware_install/venv/bin/python ./setup.py install
### Installs
RUN /tmp/piaware_install/venv/bin/cxfreeze --target-dir=/usr/lib/piaware/helpers --include-modules=imp /tmp/piaware_install/venv/bin/fa-mlat-client
RUN chmod +x /usr/lib/piaware/helpers/fa-mlat-client
### PiAware
WORKDIR /tmp/piaware_install
RUN git clone https://github.com/flightaware/piaware.git piaware && \
        cd piaware && \
        git checkout -q --detach v3.5.3 -- && \
        git --no-pager log -1 --oneline
WORKDIR /tmp/piaware_install
RUN yum install -y \
	openssl-perl
RUN make -C piaware DESTDIR=/ install INSTALL_SUDOERS=1 SYSTEMD= SYSVINIT= TCLLAUNCHER=/usr/bin/tcllauncher

# FR24FEED
WORKDIR /fr24feed
RUN wget https://repo-feed.flightradar24.com/linux_x86_64_binaries/fr24feed_1.0.18-5_amd64.tgz \
    && tar -xvzf *amd64.tgz
COPY fr24feed.ini /etc/

# Supervisor
RUN yum install -y \
	supervisor
COPY supervisord.conf /etc/supervisord.d/ads-b.ini
RUN /usr/bin/systemctl enable supervisord

EXPOSE 8754 8080 30001 30002 30003 30004 30005 30104 

### Kick it off
CMD ["/usr/sbin/init"]
