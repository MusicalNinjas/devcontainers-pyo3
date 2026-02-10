FROM fedora:latest@sha256:781b7642e8bf256e9cf75d2aa58d86f5cc695fd2df113517614e181a5eee9138

# ---
# Setup base system ...
# ---

# Enable man pages by commenting out the nodocs flag
COPY <<EOF /etc/dnf/dnf.conf
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
best=False
skip_if_unavailable=True
install_weak_deps=False
assumeyes=True
# tsflags=nodocs
EOF


# Create the default user
ARG USERNAME=pyo3
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
RUN groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
 && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

# ---
# Install ...
# ---

# Man pages for all the stuff which is already installed, man itself and basic manpages
RUN dnf update \
 && dnf reinstall --skip-unavailable $(dnf list --installed | awk '{print $1}') \
 && dnf install \
        man \
        man-db \
        man-pages

# Basic development tools
RUN dnf install \
        bash-completion \
        git \
        just \
        which

# Python
RUN dnf install \
        python \
        python-pip

# Rust goes in /opt with a dedicated rust group so we don't end up with system and user installs: this is a single user system.
# + python headers
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:$PATH

RUN mkdir --mode=777 --parents $RUSTUP_HOME \
 && mkdir --mode=777 --parents $CARGO_HOME \
 && groupadd rust \
 && usermod -a -G rust root \
 && usermod -a -G rust ${USERNAME}

USER root:rust
RUN dnf install \
        clang \
        mold \
        python3-devel \
        rustup \
  # umask g+rwx for remaining commands
 && umask 0002 \
 && rustup-init -v -y \
 && rustup component add \
        clippy \
        llvm-tools \
        llvm-tools-preview \
        rustfmt \
        rust-src \
 && curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash \
 && cargo binstall --secure -y \ 
        cargo-cyclonedx \
        cargo-expand \
        cargo-machete \
        cargo-nextest \
        cargo-udeps \
        grcov \
        mdbook \
 && cat <<EOF >> ${CARGO_HOME}/config.toml
[target.'cfg(target_os = "linux")']
rustflags = ["-C", "link-arg=-fuse-ld=mold"]
EOF
USER root:root

# ---
# Final setup steps
# ---

# Set the default user
USER ${USERNAME}
