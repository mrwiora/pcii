FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ── Yocto Scarthgap (5.0 LTS) host dependencies ─────────────────────────────
# Reference: https://docs.yoctoproject.org/5.0/ref-manual/system-requirements.html
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core build tools
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    # Scripting / parsing
    gawk \
    bison \
    flex \
    # Source management
    git \
    git-lfs \
    curl \
    wget \
    ca-certificates \
    # Yocto specific
    diffstat \
    unzip \
    texinfo \
    chrpath \
    socat \
    cpio \
    xz-utils \
    zstd \
    liblz4-tool \
    lz4 \
    debianutils \
    file \
    # Python 3
    python3 \
    python3-pip \
    python3-pexpect \
    python3-git \
    python3-jinja2 \
    python3-subunit \
    python3-distutils \
    python3-setuptools \
    python3-wheel \
    # Pseudo / filesystem
    libacl1 \
    libacl1-dev \
    # Mesa / SDL (for native QEMU tests)
    libegl1-mesa \
    libsdl1.2-dev \
    mesa-common-dev \
    # Networking / misc
    iputils-ping \
    net-tools \
    rsync \
    # Terminal
    xterm \
    # Locale
    locales \
    # Compression
    zlib1g-dev \
    libbz2-dev \
    # Cross-compilation helpers
    libncurses5-dev \
    libssl-dev \
    swig \
    device-tree-compiler \
    # Screen / terminal multiplexer (useful inside container)
    tmux \
    # Sudo (must be present before sudoers.d is written below)
    sudo \
    # Misc
    less \
    vim \
    patch \
    patchutils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set up locale (required by Yocto)
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ── Create yocto user with UID/GID 1000 (matches typical host user) ──────────
ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=yocto

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} \
               --shell /bin/bash \
               --create-home \
               ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# ── Git global safe-directory (needed when workspace is mounted from host) ───
RUN git config --system --add safe.directory '*'

# ── Switch to yocto user ──────────────────────────────────────────────────────
USER ${USERNAME}
WORKDIR /workdir

# Configure git identity (BitBake operations may invoke git)
RUN git config --global user.email "yocto@build.local" \
    && git config --global user.name "Yocto Builder" \
    && git config --global safe.directory '*'

CMD ["/bin/bash"]
