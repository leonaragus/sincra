FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Instalar dependencias básicas
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Instalar Flutter SDK estable
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Configurar Flutter
RUN flutter config --no-analytics
RUN flutter doctor
RUN flutter config --enable-web

# Instalar Firebase Tools globalmente
RUN npm install -g firebase-tools

WORKDIR /workspaces/elevar_liquidacion