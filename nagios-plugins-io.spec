Name:		nagios-plugins-io
Version:	0.1
Release:	1%{?dist}
Summary:	Linux and Solaris disk I/O monitoring plugin for Nagios/Icinga

Group:		Applications/System
License:	GPLv2+
URL:		https://labs.ovido.at/monitoring
Source0:	check_io-%{version}.tar.gz
BuildRoot:	%{_tmppath}/check_io-%{version}-%{release}-root

%description
This plugin for Icinga/Nagios is used to monitor disk I/O utilization
on Linux and Solaris hosts and disk errors on Solaris hosts.

%prep
%setup -q -n check_io-%{version}

%build
%configure --prefix=%{_libdir}/nagios/plugins \
	   --with-nagios-user=nagios \
	   --with-nagios-group=nagios \
	   --disable-pnp-template

make all


%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT INSTALL_OPTS=""

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(0755,nagios,nagios)
%{_libdir}/nagios/plugins/check_io
%doc README INSTALL NEWS ChangeLog COPYING



%changelog
* Thu Dec 13 2012 Rene Koch <r.koch@ovido.at> 0.1-1
- Initial build.

