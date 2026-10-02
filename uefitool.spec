Name:           uefitool
Version:        A76
Release:        1%{?dist}
Summary:        UEFI firmware image viewer and editor

License:        BSD-2-Clause
URL:            https://github.com/LongSoft/UEFITool
Source0:        uefitool-%{version}.tar.gz

Provides:       UEFITool = %{version}-%{release}
Provides:       uefiextract = %{version}-%{release}
Provides:       UEFIExtract = %{version}-%{release}
Provides:       uefifind = %{version}-%{release}
Provides:       UEFIFind = %{version}-%{release}

BuildRequires:  gcc-c++
BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  cmake(Qt6Widgets)
BuildRequires:  desktop-file-utils
BuildRequires:  appstream

%description
UEFITool is a versatile cross-platform application that parses UEFI PI-compatible
firmware images into a tree structure, verifies image integrity, and provides a
graphical interface to manipulate image elements.

This package also includes:
- uefiextract: Command-line tool to extract all parsed structures from firmware images
- uefifind: Command-line tool to search firmware images for GUIDs, text, or hex patterns

%prep
%autosetup -p1 -n %{name}-%{version}

%build
%cmake -G Ninja
%cmake_build

%install
%cmake_install

# Install compatibility symlinks
ln -s uefitool %{buildroot}%{_bindir}/UEFITool
ln -s uefiextract %{buildroot}%{_bindir}/UEFIExtract
ln -s uefifind %{buildroot}%{_bindir}/UEFIFind

# Install AppStream metadata and matching desktop symlink
install -D -p -m 0644 appstream/appdata.xml %{buildroot}%{_metainfodir}/com.github.LongSoft.UEFITool.metainfo.xml
ln -s uefitool.desktop %{buildroot}%{_datadir}/applications/com.github.LongSoft.UEFITool.desktop

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/uefitool.desktop
appstreamcli validate --no-net %{buildroot}%{_metainfodir}/com.github.LongSoft.UEFITool.metainfo.xml

%files
%license LICENSE.md
%doc README.md
%{_bindir}/uefitool
%{_bindir}/UEFITool
%{_bindir}/uefiextract
%{_bindir}/UEFIExtract
%{_bindir}/uefifind
%{_bindir}/UEFIFind
%{_datadir}/applications/uefitool.desktop
%{_datadir}/applications/com.github.LongSoft.UEFITool.desktop
%{_metainfodir}/com.github.LongSoft.UEFITool.metainfo.xml
%{_datadir}/icons/hicolor/*/apps/uefitool.png

%changelog
* Fri Oct 02 2026 Antigravity <antigravity@local> - A76-1
- Initial RPM package for Fedora Asahi Remix
