# `install` phase: install stuff needed for the `script` phase

set -ex

. $(dirname $0)/utils.sh

install_c_toolchain() {
    case $TARGET in
        aarch64-unknown-linux-gnu)
            sudo apt-get install -y --no-install-recommends \
                 gcc-aarch64-linux-gnu libc6-arm64-cross libc6-dev-arm64-cross
            ;;
        *)
            # For other targets, this is handled by addons.apt.packages in .travis.yml
            ;;
    esac
}

install_rustup() {
    # uninstall the rust toolchain installed by travis, we are going to use rustup
    sh ~/rust/lib/rustlib/uninstall.sh

    curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain=$TRAVIS_RUST_VERSION

    rustc -V
    cargo -V
}

install_standard_crates() {
    if [ $(host) != "$TARGET" ]; then
        rustup target add $TARGET
    fi
}

configure_cargo() {
    local prefix=$(gcc_prefix)

    if [ ! -z $prefix ]; then
        # information about the cross compiler
        ${prefix}gcc -v

        # tell cargo which linker to use for cross compilation
        mkdir -p .cargo
        cat >>.cargo/config <<EOF
[target.$TARGET]
linker = "${prefix}gcc"
EOF
    fi
}

main() {
    install_c_toolchain
    install_rustup
    install_standard_crates
    configure_cargo

    case "$TRAVIS_OS_NAME" in
        linux)
            # Not sure what I am doing wrong, but apt-get cannot handle
            # libssl:arm* - it generates a conflict which is unresolvable
            # and then fails the entire build
            sudo apt-get install -y aptitude

            # libssl-dev is in backports for ARM
            if [[ "$(architecture $TARGET)" == arm* ]]; then

              sudo sed -i 's/deb /deb [arch=amd64] /' /etc/apt/sources.list
              sudo sh -c 'echo "deb [arch=arm64,armhf] http://ports.ubuntu.com trusty main universe" >> /etc/apt/sources.list'
            fi

            sudo aptitude update -q2
            sudo aptitude install -y --without-recommends libssl-dev:$(architecture $TARGET) gcc-multilib
            ;;
        osx)
            brew update
            brew install openssl
            ;;
    esac
}

main
