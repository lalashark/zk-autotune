FROM node:18-bullseye

# 基本工具 + 建置 circom 需要的套件
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl ca-certificates pkg-config \
    libssl-dev time parallel jq && \
    rm -rf /var/lib/apt/lists/*

# 安裝 Rust（用來從原始碼編譯 circom）
ENV CARGO_HOME=/opt/rust/cargo \
    RUSTUP_HOME=/opt/rust/rustup \
    PATH=/opt/rust/cargo/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.74.1

# 從來源碼編譯並安裝 circom v2.1.6（與我們的腳本相容）
RUN git clone --depth 1 --branch v2.1.6 https://github.com/iden3/circom.git /tmp/circom && \
    cd /tmp/circom && \
    cargo build --release && \
    install -Dm755 target/release/circom /usr/local/bin/circom && \
    cd / && rm -rf /tmp/circom

# 安裝 snarkjs：鎖 0.6.11；若取不到則退回 0.6.5
RUN bash -lc 'npm i -g snarkjs@0.6.11 || npm i -g snarkjs@0.6.5'

WORKDIR /work

# 版本確認（方便除錯）
# 版本確認（可選）
RUN circom --version || true
RUN snarkjs --version || snarkjs -h || true
RUN apt-get update && apt-get install -y build-essential time jq parallel bc && rm -rf /var/lib/apt/lists/*


