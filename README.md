# Quantum ESPRESSO Build and Install Script

This script configures, builds, and installs Quantum ESPRESSO using GCC and OpenMPI provided through the cluster module system.

It is designed to work regardless of the directory from which the script is executed.

## Requirements

The system must provide:

* Bash
* Environment Modules or Lmod
* GCC module
* OpenMPI module
* `make`
* `git`
* `mpicc`
* `mpifort`

The default modules are:

```text
gcc/10.4.0
openmpi/5.0.2
```

The GCC module is loaded first because it may expose the corresponding OpenMPI module through `MODULEPATH`.

## Directory Layout

The script supports two common layouts.

### Script inside the Quantum ESPRESSO source tree

```text
q-e/
├── configure
├── CMakeLists.txt
├── install.sh
├── PW/
├── Modules/
└── ...
```

Run:

```bash
./install.sh
```

The default build and installation directories will be created beside the `q-e` source directory:

```text
project/
├── q-e/
├── build-make/
└── install/
```

### Script beside the Quantum ESPRESSO source tree

```text
project/
├── install.sh
└── q-e/
    ├── configure
    ├── CMakeLists.txt
    └── ...
```

Run:

```bash
./install.sh
```

The script automatically detects `q-e/` as the source directory.

## Basic Usage

Make the script executable:

```bash
chmod +x install.sh
```

Then run:

```bash
./install.sh
```

By default, the script will:

1. Load `gcc/10.4.0`.
2. Load `openmpi/5.0.2`.
3. Initialize Git submodules if required.
4. Configure Quantum ESPRESSO with MPI support.
5. Enable OpenMP support.
6. Disable ScaLAPACK.
7. Build Quantum ESPRESSO.
8. Install it into the `install/` directory.
9. Verify that `bin/pw.x` was successfully installed.

The effective configure options are approximately:

```bash
./configure \
    --prefix=<install-directory> \
    --enable-parallel \
    --enable-openmp \
    --with-scalapack=no
```

## Environment Variables

The script can be customized using environment variables without modifying the script itself.

### `QE_SOURCE_DIR`

Explicitly specify the Quantum ESPRESSO source directory.

```bash
QE_SOURCE_DIR=/path/to/q-e ./install.sh
```

### `QE_BUILD_DIR`

Specify a custom build directory.

```bash
QE_BUILD_DIR=/scratch/$USER/qe-build ./install.sh
```

Default:

```text
<work-root>/build-make
```

### `QE_INSTALL_PREFIX`

Specify the installation directory.

```bash
QE_INSTALL_PREFIX=$HOME/software/qe ./install.sh
```

Default:

```text
<work-root>/install
```

After installation, executables will be located in:

```text
<QE_INSTALL_PREFIX>/bin
```

### `QE_GCC_MODULE`

Override the GCC module.

```bash
QE_GCC_MODULE=gcc/12.2.0 ./install.sh
```

Default:

```text
gcc/10.4.0
```

### `QE_MPI_MODULE`

Override the MPI module.

```bash
QE_MPI_MODULE=openmpi/5.0.5 ./install.sh
```

Default:

```text
openmpi/5.0.2
```

### `QE_JOBS`

Control the number of parallel compilation jobs.

```bash
QE_JOBS=16 ./install.sh
```

This results in approximately:

```bash
make -j 16
```

If `QE_JOBS` is not specified, the script detects the available CPU count but limits the default to 8 jobs to avoid consuming an entire shared login node.

On a dedicated compute node, a larger value can be specified explicitly.

For example:

```bash
QE_JOBS=64 ./install.sh
```

### `QE_ENABLE_OPENMP`

Control OpenMP support.

OpenMP is enabled by default:

```bash
QE_ENABLE_OPENMP=1 ./install.sh
```

To disable it:

```bash
QE_ENABLE_OPENMP=0 ./install.sh
```

### `QE_CLEAN_BUILD`

Remove the existing build directory before configuring.

```bash
QE_CLEAN_BUILD=1 ./install.sh
```

This is useful when changing compilers, MPI implementations, or major configure options.

The script includes safety checks to prevent accidental removal of the source directory, script directory, or `/`.

### `QE_MAKE_TARGETS`

Override the default Make target.

The default is:

```text
all
```

For example:

```bash
QE_MAKE_TARGETS=pw ./install.sh
```

The available targets depend on the Quantum ESPRESSO version and its Makefiles.

## Example: Clean Build with 32 Compilation Jobs

```bash
QE_CLEAN_BUILD=1 \
QE_JOBS=32 \
./install.sh
```

## Example: Custom Build and Install Directories

```bash
QE_BUILD_DIR=/scratch/$USER/qe-build \
QE_INSTALL_PREFIX=$HOME/software/qe \
QE_JOBS=16 \
./install.sh
```

## Example: Custom Toolchain

```bash
QE_GCC_MODULE=gcc/12.2.0 \
QE_MPI_MODULE=openmpi/5.0.5 \
QE_CLEAN_BUILD=1 \
./install.sh
```

A clean build is recommended when changing the compiler or MPI implementation.

## Using the Installed Quantum ESPRESSO

After a successful installation, add the Quantum ESPRESSO executables to the current shell's `PATH`:

```bash
export PATH="/path/to/install/bin:$PATH"
```

For the default installation layout, this may be:

```bash
export PATH="$(pwd)/install/bin:$PATH"
```

Verify the installation:

```bash
which pw.x
```

or:

```bash
pw.x --help
```

A typical MPI execution is:

```bash
mpirun -np 8 pw.x -in input.in > output.out
```

The exact MPI launch command may depend on the cluster scheduler and MPI configuration.

## Build Configuration

The default build configuration is:

```text
Compiler:       GCC
MPI:            OpenMPI
MPI support:    Enabled
OpenMP:         Enabled
ScaLAPACK:      Disabled
Build type:     Out-of-source
```

The source, build, and installation trees are kept separate:

```text
project/
├── q-e/          # Quantum ESPRESSO source
├── build-make/   # Generated files and compiled objects
└── install/      # Installed executables
    └── bin/
        └── pw.x
```

## Error Handling

The script uses strict Bash error handling.

If a command fails, execution stops immediately and reports the approximate line at which the failure occurred:

```text
[qe-install] ERROR: command failed at line <line> (exit <status>)
```

The script also checks that:

* the Quantum ESPRESSO source tree exists;
* the working directory is writable;
* the requested modules are available;
* `make`, `git`, `mpicc`, and `mpifort` exist;
* `pw.x` exists after installation.

A successful installation ends with output similar to:

```text
[qe-install] installation completed successfully
[qe-install] executables: /path/to/install/bin
[qe-install] for this shell: export PATH="/path/to/install/bin:${PATH}"
```
