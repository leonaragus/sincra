FROM mcr.microsoft.com/devcontainers/dart:1-3.3-bullseye

# Install Flutter
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter

# Add Flutter to PATH
ENV PATH="\$PATH:/usr/local/flutter/bin"

# Enable web support
RUN flutter doctor
RUN flutter config --enable-web

# Verify installation
RUN flutter --version
RUN flutter doctor