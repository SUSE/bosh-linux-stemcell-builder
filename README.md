# bosh-linux-stemcell-builder

Tools for creating openSUSE and SLES based stemcells.

The stemcell is based off from a parent image, here called ``os-image`` which can be used as a source for composing images that can be run in different enviroments (openstack, GCE, etc.).

First make sure you have a local copy of this repository and have Docker and git installed on the machine.

## Docker development workflow

For Opensuse and SLE based stemcells, you can use the make targets to build the os-image and the fissile stemcell automatically without having to setup an environment manually ( See [Setup a local build environment] below ).

Requirements: Docker running on the host machine


### Opensuse

For building the latest available openSUSE-based stemcell, you only need to type inside your check out of this repository:

    $> make all

You will find the os-image under the ```build/``` directory, and the stemcell image in your docker host.

### SLE

    $> STEMCELL_DOCKER_REPO=https://github.com/SUSE/fissile-stemcell-SLE STEMCELL_BRANCH=master VERSION=sles,12 make all

### Customize the building steps

There are variables that you can use to customize the building process.

Os-image options:

* ***VERSION***: By default it is set to ```opensuse,leap``` . It's the version that the os-image is based against. For e.g. to build a os-image for sle12, ```VERSION=sles,12```.
* ***OS_IMAGE***: Defaults to ```suse_os_image.tgz```, it's the name of the os-image produced that you can find under ```build/```

Stemcell options:

* ***STEMCELL_IMAGE***: Name of the resulting stemcell image name (defaults to ```suse-os-image-stemcell```)
* ***STEMCELL_BRANCH***: Checkout branch for the stemcell sources (Defaults to ```42.3```)
* ***STEMCELL_DOCKER_REPO***: Repository containing the Dockerfile used to produce the stemcell (which is based off from the os-image previously built, defaults: ```https://github.com/SUSE/fissile-stemcell-openSUSE.git```)
* ***STEMCELL_VERSION***: Tag of the resulting stemcell image name (defaults to ```STEMCELL_BRANCH```)

You can also build the os-image and the stemcell separately.

To build the os-image only, you can use:

    $> make os-image

To build the fissile stemcell:

    $> make fissile-stemcell

## Setup a local build environment

 If you already have a stemcell-building environment set up and ready, skip to the **Build Steps** section. Otherwise, follow one of these two methods before trying to run the commands in **Build Steps**.

The Docker-based environment files are located in `ci/docker/os-image-stemcell-builder`...

    host$ cd ci/docker/os-image-stemcell-builder

If you are not running on Linux or you do not have Docker installed, use `vagrant` to start a new VM which has Docker, and then change back into the `./docker` directory...

    host$ vagrant up
    host$ vagrant ssh

Once you have Docker running, run `./run`...

    vagrant$ /opt/bosh/ci/docker/run os-image-stemcell-builder
    container$ whoami
    ubuntu

*You're now ready to continue from the **Build Steps** section.*

**Troubleshooting**: if you run into issues, try destroying any existing VM, update your box, and try again...

    host$ vagrant destroy
    host$ vagrant box update


### Build Steps

At this point, you should be ssh'd and running within your container in the `bosh-linux-stemcell-builder` directory. Start by installing the latest dependencies before continuing to a specific build task...

    $ echo $PWD
    /opt/bosh
    $ bundle install --local


### Build an OS image

An OS image is a tarball that contains a snapshot of an entire OS filesystem that contains all the libraries and system utilities that the BOSH agent depends on. It does not contain the BOSH agent or the virtualization tools: there is [a separate Rake task](#with-local-os-image) that adds the BOSH agent and a chosen set of virtualization tools to any base OS image, thereby producing a stemcell.

The OS Image should be rebuilt when you are making changes to which packages we install in the operating system, or when making changes to how we configure those packages, or if you need to pull in and test an updated package from upstream.

    $ mkdir -p $PWD/tmp
    $ bundle exec rake stemcell:build_os_image[ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz]

The arguments to `stemcell:build_os_image` are:

1. *`operating_system_name`* identifies which type of OS to fetch. Determines which package repository and packaging tool will be used to download and assemble the files. Must match a value recognized by the  [OperatingSystem](bosh-stemcell/lib/bosh/stemcell/operating_system.rb) module. Currently, `ubuntu` `centos` and `rhel` are recognized.
2. *`operating_system_version`* an identifier that the system may use to decide which release of the OS to download. Acceptable values depend on the operating system. For `ubuntu`, use `trusty`. For `centos` or `rhel`, use `7`.
3. *`os_image_path`* the path to write the finished OS image tarball to. If a file exists at this path already, it will be overwritten without warning.


#### Special requirements for building an openSUSE image

The openSUSE image is built using [Kiwi](http://opensuse.github.io/kiwi/) which is not available in the normal builder container. For that reason a special container has to be used. All required steps are described in the [documentation](./ci/docker/suse-os-image-stemcell-builder/README.md).

#### How to run tests for OS Images

The OS tests are meant to be run agains the OS environment to which they belong. When you run the `stemcell:build_os_image` rake task, it will create a .raw OS image that it runs the OS specific tests against. You will need to run the rake task the first time you create your docker container, but everytime after, as long as you do not destroy the container, you should be able to just run the specific tests.

To run the `centos_7_spec.rb` tests for example you will need to:

* `bundle exec rake stemcell:build_os_image[centos,7,$PWD/tmp/centos_base_image.tgz]`
* -make changes-

Then run the following:

    cd /opt/bosh/bosh-stemcell; OS_IMAGE=/opt/bosh/tmp/centos_base_image.tgz bundle exec rspec -fd spec/os_image/centos_7_spec.rb


### Building a Stemcell

The stemcell should be rebuilt when you are making and testing BOSH-specific changes on top of the base OS image such as new bosh-agent versions, or updating security configuration, or changing user settings.

#### with published OS image

The last two arguments to the rake command are the S3 bucket and key of the OS image to use (i.e. in the example below, the .tgz will be downloaded from [http://bosh-os-images.s3.amazonaws.com/bosh-centos-7-os-image.tgz](http://bosh-os-images.s3.amazonaws.com/bosh-centos-7-os-image.tgz)). More info at OS\_IMAGES.

    $ bundle exec rake stemcell:build[aws,xen,ubuntu,trusty,"1234.56"]

The final argument, which specifies the build number, is optional and will default to '0000'

#### with local OS image

If you want to use an OS Image that you just created, use the `stemcell:build_with_local_os_image` task, specifying the OS image tarball.

    $ bundle exec rake stemcell:build_with_local_os_image[aws,xen,ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz,"1234.56"]

The final argument, which specifies the build number, is optional and will default to '0000'

You can also download OS Images from the public S3 bucket.  Download information
and metadata can be found in the corresponding [metalink files](./bosh-stemcell/image-metalinks).
Public OS images can be obtained by:

```
# latest ubuntu-trusty
$ bundle exec rake stemcell:download_os_image[ubuntu,trusty]

# latest centos-7
$ bundle exec rake stemcell:download_os_image[centos,7]
```

**NOTE**: The `download_os_image` rake task has a dependency on the
[meta4 binary](https://github.com/dpb587/metalink/releases).

#### How to run tests for Stemcell
When you run the `stemcell:build_with_local_os_image` or `stemcell:build` rake task, it will create a stemcell that it runs the stemcell specific tests against. You will need to run the rake task the first time you create your docker container, but everytime after, as long as you do not destroy the container, you should be able to just run the specific tests.

To run the stemcell tests when building against local OS image you will need to:

* `bundle exec rake stemcell:build_with_local_os_image[aws,xen,ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz]`
* -make test changes-

Then run the following:
```sh
    $ cd /opt/bosh/bosh-stemcell; \
    STEMCELL_IMAGE=/mnt/stemcells/aws/xen/ubuntu/work/work/aws-xen-ubuntu.raw \
    STEMCELL_WORKDIR=/mnt/stemcells/aws/xen/ubuntu/work/work/chroot \
    OS_NAME=ubuntu \
    bundle exec rspec -fd --tag ~exclude_on_aws \
    spec/os_image/ubuntu_trusty_spec.rb \
    spec/stemcells/ubuntu_trusty_spec.rb \
    spec/stemcells/go_agent_spec.rb \
    spec/stemcells/aws_spec.rb \
    spec/stemcells/stig_spec.rb \
    spec/stemcells/cis_spec.rb
```

## ShelloutTypes

In pursuit of more robustly testing, we wrote our testing library for stemcell contents, called ShelloutTypes.

The ShelloutTypes code has its own unit tests, but require root privileges and an ubuntu chroot environment to run. For this reason, we use the `bosh/main-ubuntu-chroot` docker imagefor unit tests. To run these unit tests locally, run:

```
$ docker run bosh/main-ubuntu-chroot    # now in /opt/bosh
$ source /etc/profile.d/chruby.sh
$ chruby 2.3.1

$ #create user for ShelloutTypes::File tests
$ chroot /tmp/ubuntu-chroot /bin/bash -c 'useradd -G nogroup shellout'

$ bundle install --local
$ cd bosh-stemcell
$ bundle exec rspec spec/ --tag shellout_types

```

The above strategy is derived from our CI unit testing job's script.

## Troubleshooting

If you find yourself debugging any of the above processes, here is what you need to know:

0. Most of the action happens in Bash scripts, which are referred to as _stages_, and can be found in `stemcell_builder/stages/<stage_name>/apply.sh`.
0. You should make all changes on your local machine, and sync them over to the AWS stemcell building machine using `vagrant provision remote` as explained earlier on this page.
0. While debugging a particular stage that is failing, you can resume the process from that stage by adding `resume_from=<stage_name>` to the end of your `bundle exec rake` command. When a stage's `apply.sh` fails, you should see a message of the form `Can't find stage '<stage>' to resume from. Aborting.` so you know which stage failed and where you can resume from after fixing the problem.

For example:

    $ bundle exec rake stemcell:build_os_image[ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz] resume_from=rsyslog_config


## Pro Tips

* If the OS image has been built and so long as you only make test case modifications you can just rerun the tests (without rebuilding OS image). Details in section `How to run tests for OS Images`

* If the Stemcell has been built and so long as you only make test case modifications you can rerun the tests (without rebuilding Stemcell. Details in section `How to run tests for Stemcell`

* It's possible to verify OS/Stemcell changes without making adeployment using the stemcell. For an AWS specific ubuntu stemcell, the filesytem is available at `/mnt/stemcells/aws/xen/ubuntu/work/work/chroot`


## Rebuilding the Image

The Docker image is published to [`bosh/os-image-stemcell-builder`](https://hub.docker.com/r/bosh/os-image-stemcell-builder/).

If you need to rebuild the image, first download the ovftool installer from VMWare. Details about this can be found at [my.vmware.com](https://my.vmware.com/group/vmware/details?downloadGroup=OVFTOOL410&productId=489). Specifically...

0. Download the `*.bundle` file to the docker image directory (`ci/docker/os-image-stemcell-builder`)
0. When upgrading versions, update `Dockerfile` with the new file path and SHA

Rebuild the container with the `build` script...

    vagrant$ ./build os-image-stemcell-builder

When ready, `push` to DockerHub and use the credentials from LastPass...

    vagrant$ cd os-image-stemcell-builder
    vagrant$ ./push
