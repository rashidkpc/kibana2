Name:           kibana
Version:        0.1.5
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

%build
# do nothing

%install
# untar kibana into the document root
cd ${RPM_BUILD_ROOT}
mkdir -p "${RPM_BUILD_ROOT}/var/www/html/%{name}"
tar -zxvf %SOURCE0 --strip-components 1 \
                   --exclude=kibana-httpd.conf \
                   --exclude=kibana.spec \
                   -C ${RPM_BUILD_ROOT}/var/www/html/%{name} 

mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d
tar -zxvf %SOURCE0 --strip-components 1 \
                   --to-stdout \
                   */kibana-httpd.conf > ${RPM_BUILD_ROOT}%{_sysconfdir}/httpd/conf.d/kibana.conf

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
/var/www/html
%config(noreplace) /var/www/html/%{name}/config.php
%config(noreplace) %attr(0644,root,root) /etc/httpd/conf.d/kibana.conf

%changelog
* Fri May 18 2012 David Castro arimus@gmail.com 0.1.5-1
- Modified spec to work with rpmbuild -ta kibana-0.1.5.tar.gz style builds,
  which only requires that the github-style tarballs are renamed to
  kibana-X.Y.Z.tar.gz

* Fri Apr 06 2012 David Castro arimus@gmail.com 0.1.4
- Initial spec
