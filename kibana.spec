%define debug_package %{nil}

Name:           kibana
Version:        0.1.6
Release:        1%{?dist}
Summary:        logstash is a tool for managing events and logs.

Group:          System Environment/Daemons
License:        MIT
URL:            http://rashidkpc.github.com/Kibana/
Source0:        %{name}-%{version}.tar.gz

BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch

Requires:       php >= 5.2

%description
Kibana is an open source (MIT License), browser based interface to Logstash and ElasticSearch

%prep
rm -rf "${RPM_BUILD_ROOT}"
mkdir -p "${RPM_BUILD_ROOT}/var/www/html/%{name}"

%build
# do nothing

%install
# untar kibana into the document root
cd ${RPM_BUILD_ROOT}
tar -zxvf %SOURCE0 --strip-components 1 -C ${RPM_BUILD_ROOT}/var/www/html/%{name}

mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d
install -m 644 $RPM_SOURCE_DIR/kibana-httpd.conf \
        $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d/kibana.conf

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
/var/www/html
%config(noreplace) /var/www/html/%{name}/config.php
%config(noreplace) /etc/httpd/conf.d/kibana.conf

%changelog
* Wed May 16 2012 David Castro arimus@gmail.com 0.1.6-1
- Spec updated for master branch
* Fri Apr 06 2012 David Castro arimus@gmail.com 0.1.5-1
- Initial spec
