%define		_profile c7-flightradar24
%define         _module systemdock-%{_profile}

# SVAROG-related variables
%{!?svn_revision:%define svn_revision 1}
# COMPATIBILITY FIX: Jenkins job name is neccessary to make build root unique (for CentOS5 and earlier)
%{!?JOB_NAME:%define JOB_NAME standalone}


Name:		%{_module}
Version:	0.1
Release:	%{svn_revision}%{?dist}
Summary:	SystemDock profile to run FlightRadar24+PiAware container as systemd service

Group:		Tools/Other
License:	GPLv3
URL:		https://github.com/rpavlyuk/docker-fr24feed-piaware-dump1090-mutability.git
Packager:       Roman Pavlyuk <roman.pavlyuk@gmail.com>
Source:         %{_module}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)-%{JOB_NAME}
BuildArch:      noarch

Requires:	systemdock
Requires:	systemd

%description
SystemDock profile to run FlightRadar24+PiAware container as systemd service

%prep
%setup -n %{_module}

%build
# Nothing

%install
%make_install DESTDIR=$RPM_BUILD_ROOT

rm -rf $RPM_BUILD_ROOT%{_unitdir}
mkdir -p $RPM_BUILD_ROOT%{_unitdir}
ln -s %{_sysconfdir}/systemdock/containers.d/%{_profile}/%{_module}.service $RPM_BUILD_ROOT%{_unitdir}/%{_module}.service

%files
%doc README.md

%config(noreplace) %{_sysconfdir}/systemdock/containers.d/%{_profile}/config.yml
%{_sysconfdir}/systemdock/containers.d/%{_profile}/%{_module}.service

%config(noreplace) %{_sysconfdir}/modprobe.d/rtlXXXX-blacklist.conf

%{_unitdir}/%{_module}.service

%changelog

