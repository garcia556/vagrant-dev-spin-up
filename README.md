# Vagrant Spin-up

Creates a VM with Linux (Ubuntu by default) that is accessiblt directly by host-only network

## Usage
`./create.sh` will do all the work asking user for all the required input

Since Vagrant keeps all its files in the current directory my usual scenario is to create a new project directory and to clone this script to some dedicated directory like `git clone ... vm; cd vm; ./create.sh`

### Prerequisites
- macOS (might work on Linux though)
- VirtualBox (I use `brew cask` version, for standalone installer `VirtualBox` provider must be used)
- Vagrant (same thing - tested on `brew cask` version)

### Some important specifics
- disk size is 50Gb (third party plugin is used)
- login/password: `root`/`root`
- `sshd` config:
  - password authentication is **enabled**
  - `root` login is **enabled**

Thus VM is ready to be provisioned. I use Fabric scripts like [this]() one.

#### macOS specific
- `gsed` (can be installed with `brew install gnu-sed`)

