# Compiling and Building UEFITool

This guide covers building **UEFITool**, **UEFIExtract**, and **UEFIFind** from source, as well as packaging RPMs for Linux distributions (Fedora, RHEL, CentOS, Fedora Asahi Remix, etc.).

---

## Table of Contents

- [Components](#components)
- [Automated Build & Test Script (build.sh)](#automated-build--test-script-buildsh)
- [Prerequisites & Dependencies](#prerequisites--dependencies)
  - [Fedora / RHEL / CentOS / Asahi Remix](#fedora--rhel--centos--asahi-remix)
  - [Ubuntu / Debian](#ubuntu--debian)
  - [Arch Linux / Manjaro](#arch-linux--manjaro)
  - [macOS](#macos)
- [Building with CMake (Recommended)](#building-with-cmake-recommended)
  - [Build Everything](#build-everything)
  - [Build Individual Components](#build-individual-components)
  - [System Installation](#system-installation)
- [Building with QMake (UEFITool GUI)](#building-with-qmake-uefitool-gui)
- [Building with Meson (CLI Utilities)](#building-with-meson-cli-utilities)
- [Building RPM Package (Fedora / RHEL)](#building-rpm-package-fedora--rhel)
- [Troubleshooting & Tips](#troubleshooting--tips)

---

## Components

The repository produces three main tools:

| Binary | Description | GUI / CLI | Framework |
| :--- | :--- | :--- | :--- |
| `uefitool` | UEFI firmware image viewer, tree browser, and editor | GUI | C++11, Qt6 (or Qt5) |
| `uefiextract` | Tool to dump and unpack parsed UEFI firmware structures | CLI | C++11 (no Qt dependency) |
| `uefifind` | Search utility for GUIDs, text strings, and hex patterns | CLI | C++11 (no Qt dependency) |

---

## Automated Build & Test Script (build.sh)

An all-in-one automation script [`build.sh`](build.sh) is provided in the repository root.

```bash
# 1. Compile everything in Release mode
./build.sh

# 2. Compile and immediately run verification tests
./build.sh --test

# 3. Build RPM packages (binary + source) into dist/
./build.sh rpm

# 4. Clean, build, test, and package RPM in one step
./build.sh all

# 5. Install compiled binaries
sudo ./build.sh install
```

### Script Commands and Flags

| Command / Flag | Action |
| :--- | :--- |
| `build` (default) | Configures and compiles all components via CMake + Ninja/Make |
| `test` / `-t` | Runs test suite verifying version output, help options, and GUI libraries |
| `rpm` / `-r` | Generates source tarball and builds `.rpm` packages via `rpmbuild` |
| `clean` / `-c` | Cleans `build/` and `dist/` directories |
| `install` | Installs targets to `--prefix` (default: `/usr/local`) |
| `all` | Sequentially cleans, builds, tests, and builds RPM packages |
| `-d`, `--debug` | Compiles with Debug symbols (`-DCMAKE_BUILD_TYPE=Debug`) |
| `-j <N>` | Sets compilation jobs (default: detected CPU count) |


---

## Prerequisites & Dependencies

To compile UEFITool, you need a C++11 capable compiler (`gcc` or `clang`), `cmake` (version 3.22 or higher), and the Qt6 development libraries.

### Fedora / RHEL / CentOS / Asahi Remix

```bash
sudo dnf install -y \
    gcc-c++ \
    cmake \
    ninja-build \
    qt6-qtbase-devel \
    desktop-file-utils \
    appstream
```

*(For RPM packaging, also install `rpm-build` and `rpmdevtools`)*.

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    ninja-build \
    qt6-base-dev \
    libgl1-mesa-dev
```

### Arch Linux / Manjaro

```bash
sudo pacman -S --needed \
    base-devel \
    cmake \
    ninja \
    qt6-base
```

### macOS

Using [Homebrew](https://brew.sh):

```bash
brew install cmake ninja qt@6
export CMAKE_PREFIX_PATH="$(brew --prefix qt@6)"
```

---

## Building with CMake (Recommended)

CMake is the primary build system and builds all three components simultaneously.

### Build Everything

1. Clone the repository and checkout the `new_engine` branch:
   ```bash
   git clone -b new_engine https://github.com/LongSoft/UEFITool.git
   cd UEFITool
   ```

2. Configure and generate build files (using Ninja or Make):
   ```bash
   # Using Ninja (fastest)
   cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

   # Or standard Make
   cmake -B build -DCMAKE_BUILD_TYPE=Release
   ```

3. Compile:
   ```bash
   # Using Ninja
   cmake --build build

   # Or using Make directly
   cmake --build build -j$(nproc)
   ```

The compiled executables will be located in:
- `build/UEFITool/uefitool`
- `build/UEFIExtract/uefiextract`
- `build/UEFIFind/uefifind`

### Build Individual Components

If you only need a specific tool, point CMake directly to its subdirectory:

```bash
# Build only UEFIExtract (no Qt needed)
cmake -B build-extract -S UEFIExtract -DCMAKE_BUILD_TYPE=Release
cmake --build build-extract

# Build only UEFIFind (no Qt needed)
cmake -B build-find -S UEFIFind -DCMAKE_BUILD_TYPE=Release
cmake --build build-find

# Build only UEFITool GUI
cmake -B build-gui -S UEFITool -DCMAKE_BUILD_TYPE=Release
cmake --build build-gui
```

### System Installation

To install all tools, icons, desktop entries, and metadata to `/usr/local` (default):

```bash
sudo cmake --install build
```

To install into `/usr`:

```bash
sudo cmake --install build --prefix /usr
```

---

## Building with QMake (UEFITool GUI)

If you prefer building the GUI application with Qt's `qmake`:

```bash
cd UEFITool
qmake6 uefitool.pro   # or `qmake-qt5` for Qt5
make -j$(nproc)
```

The resulting `uefitool` binary will be created directly in the `UEFITool/` folder.

---

## Building with Meson (CLI Utilities)

The repository also includes `meson.build` for compiling the non-Qt command-line tools:

```bash
# Setup build directory
meson setup build_meson

# Build with ninja
ninja -C build_meson
```

---

## Building RPM Package (Fedora / RHEL)

A complete RPM spec file [`uefitool.spec`](uefitool.spec) is provided in the repository root.

### Step-by-step RPM compilation:

1. **Install RPM build dependencies**:
   ```bash
   sudo dnf install -y rpm-build rpmdevtools gcc-c++ cmake ninja-build qt6-qtbase-devel desktop-file-utils appstream
   ```

2. **Initialize RPM build environment**:
   ```bash
   mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
   ```

3. **Create the source tarball from git**:
   ```bash
   git archive --format=tar.gz --prefix=uefitool-A76/ HEAD -o ~/rpmbuild/SOURCES/uefitool-A76.tar.gz
   ```

4. **Copy the spec file**:
   ```bash
   cp uefitool.spec ~/rpmbuild/SPECS/
   ```

5. **Build the RPMs**:
   ```bash
   rpmbuild -ba ~/rpmbuild/SPECS/uefitool.spec
   ```

6. **Locate and install the created packages**:
   The output packages will be in `~/rpmbuild/RPMS/$(uname -m)/`:
   ```bash
   sudo dnf install ~/rpmbuild/RPMS/$(uname -m)/uefitool-A76-1.*.$(uname -m).rpm
   ```

The package installs:
- Executables: `/usr/bin/uefitool`, `/usr/bin/uefiextract`, `/usr/bin/uefifind`
- Case-compatible uppercase symlinks: `/usr/bin/UEFITool`, `/usr/bin/UEFIExtract`, `/usr/bin/UEFIFind`
- Desktop integration: `/usr/share/applications/uefitool.desktop`
- AppStream metadata: `/usr/share/metainfo/com.github.LongSoft.UEFITool.metainfo.xml`
- Icons: `/usr/share/icons/hicolor/*/apps/uefitool.png`

---

## Troubleshooting & Tips

- **Wayland / Scaling on Linux**: If you experience fractional scaling or display issues on Wayland, start UEFITool with:
  ```bash
  QT_QPA_PLATFORM=wayland uefitool
  # or force X11/XWayland
  QT_QPA_PLATFORM=xcb uefitool
  ```
- **Qt5 vs Qt6**: Qt6 is selected by default in CMake. If you need to build against Qt5, ensure Qt5 development packages are installed and pass `-DQT_VERSION_MAJOR=5` if configuring individual subprojects with Qt5 support.
