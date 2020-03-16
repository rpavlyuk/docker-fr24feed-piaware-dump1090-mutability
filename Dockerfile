FROM docker.io/rpavlyuk/c7-gcc7.3-glib2.19
MAINTAINER "Roman Pavlyuk" <roman.pavlyuk@gmail.com>

# Install libraries for PiAware
COPY srpms/ /srpms/
RUN rpm --import http://wiki.psychotic.ninja/RPM-GPG-KEY-psychotic
RUN rpm -ivh http://packages.psychotic.ninja/7/base/x86_64/RPMS/psychotic-release-1.0.0-1.el7.psychotic.noarch.rpm
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
RUN rpmbuild --define "debug_package %{nil}" --rebuild /srpms/tcllauncher-1.8-1.el7.src.rpm
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

# Envs
ENV RTL_SDR_VERSION 0.6.0
ENV FR24FEED_VERSION 1.0.18-5

# install RTL-SDR driver
RUN yum install -y \
	libusbx-devel \
	libusb-devel

WORKDIR /tmp
RUN mkdir -p /etc/modprobe.d && \
    echo 'blacklist r820t' >> /etc/modprobe.d/raspi-blacklist.conf && \
    echo 'blacklist rtl2832' >> /etc/modprobe.d/raspi-blacklist.conf && \
    echo 'blacklist rtl2830' >> /etc/modprobe.d/raspi-blacklist.conf && \
    echo 'blacklist dvb_usb_rtl28xxu' >> /etc/modprobe.d/raspi-blacklist.conf && \
    git clone -b ${RTL_SDR_VERSION} --depth 1 https://github.com/osmocom/rtl-sdr.git && \
    mkdir rtl-sdr/build && \
    cd rtl-sdr/build && \
    cmake ../ -DINSTALL_UDEV_RULES=ON -DDETACH_KERNEL_DRIVER=ON && \
    make && \
    make install && \
    ldconfig && \
    rm -rf /tmp/rtl-sdr

# Some info for debug
RUN cat /usr/local/lib/pkgconfig/librtlsdr.pc
RUN pkg-config --libs librtlsdr libusb-1.0

# libBladeRF
WORKDIR /tmp
RUN git clone --recursive https://github.com/Nuand/bladeRF.git ./bladeRF && \
	cd bladeRF && \
	mkdir -p host/build && \
	cd host/build && \
	cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DINSTALL_UDEV_RULES=ON ../
RUN make -C bladeRF/host/build && make -C bladeRF/host/build install && ldconfig

# Pre-requisites
RUN yum install -y \
	ncurses-devel

# DUMP1090
WORKDIR /tmp
RUN git clone https://github.com/flightaware/dump1090 && \
    cd dump1090 && \
    make && mkdir /usr/lib/fr24 && cp dump1090 /usr/lib/fr24/ && cp -r public_html /usr/lib/fr24/

COPY config.js /usr/lib/fr24/public_html/
RUN mkdir /usr/lib/fr24/public_html/data

# Uncomment if you want to add your upintheair.json file
#COPY upintheair.json /usr/lib/fr24/public_html/


# Installing PiAware
RUN mkdir -p /tmp/piaware_install/venv
WORKDIR /tmp/piaware_install


### Dump1090 for PiAware
RUN git clone https://github.com/flightaware/dump1090.git dump1090 && \
        cd dump1090 && \
        git checkout -q --detach v3.8.0 -- && \
        git --no-pager log -1 --oneline
WORKDIR /tmp/piaware_install
RUN make -C dump1090 RTLSDR=no BLADERF=no DUMP1090_VERSION="piaware-3.8.0" faup1090 && \
	/usr/bin/install -d /usr/lib/piaware/helpers && \
	/usr/bin/install -t /usr/lib/piaware/helpers dump1090/faup1090

# Python for MLAT
WORKDIR /tmp/piaware_install
RUN yum install -y \
	python36 \
	python36-setuptools \
	python36-devel \
	python36-pip
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
RUN wget -nv -O - 'https://files.pythonhosted.org/packages/5f/16/eab51d6571dfec2554248cb027c51babd04d97f594ab6359e0707361297d/cx_Freeze-5.1.1.tar.gz' | tar -C /tmp/piaware_install -zxf -
RUN cd cx_Freeze-5.1.1 && \
	/tmp/piaware_install/venv/bin/python ./setup.py install
### Installs
RUN /tmp/piaware_install/venv/bin/cxfreeze --target-dir=/usr/lib/piaware/helpers --include-modules=imp /tmp/piaware_install/venv/bin/fa-mlat-client
RUN chmod +x /usr/lib/piaware/helpers/fa-mlat-client

### PiAware
WORKDIR /tmp/piaware_install
RUN git clone https://github.com/flightaware/piaware.git piaware && \
        cd piaware && \
        git checkout -q --detach v3.8.0 -- && \
        git --no-pager log -1 --oneline
WORKDIR /tmp/piaware_install
RUN yum install -y \
	openssl-perl

RUN make -C piaware DESTDIR=/ install INSTALL_SUDOERS=1 SYSTEMD= SYSVINIT= TCLLAUNCHER=/usr/bin/tcllauncher && \
	ln -s /usr/lib/piaware /usr/share/tcl8.6/piaware && \
	ln -s /usr/lib/piaware-config /usr/share/tcl8.6/piaware-config && \
	ln -s /usr/lib/piaware-status /usr/share/tcl8.6/piaware-status && \
	ln -s /usr/lib/piaware_packages /usr/share/tcl8.6/ && \
	ln -s /usr/lib/fa_adept_codec /usr/share/tcl8.6/ && echo "TCL Libs Installed"

# fix TCL file to include ITCL 4
RUN perl -pi -e "s|Itcl\ 3\.4|Itcl\ 4|gi" /usr/share/tcl8.6/piaware/faup.tcl

#DUMP987
RUN yum install -y \
	boost169-devel

 WORKDIR /tmp/piaware_install
RUN git clone https://github.com/flightaware/dump978.git dump978 && \
	cd dump978 && \
	git checkout -q --detach v3.8.0 -- && \
        git --no-pager log -1 --oneline

# RUN perl -pi -e "s|boost_|libboost_|gi" dump978/Makefile
RUN perl -pi -e "s|\-Ilibs|-Ilibs\ \-I\/usr\/include\/boost169\ \-Wl\,\-\-verbose\ \-L\/usr\/lib64\/boost169\ \-D_GLIBCXX_USE_CXX11_ABI\=0|gi" dump978/Makefile
	
RUN make -C dump978 faup978 VERSION=3.8.0 -I/usr/include/boost169 && \
	install -d /usr/lib/piaware/helpers && \
	install -t /usr/lib/piaware/helpers dump978/faup978

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
