# =============================================================================
# Dockerfile for Chandra OCR on RunPod Serverless
# =============================================================================
# We use a minimal CUDA devel image instead of RunPod's PyTorch image
# because chandra-ocr requires torch>=2.8.0 and the RunPod image ships 2.4.0.
# Using nvidia/cuda as base avoids version conflicts entirely.
# =============================================================================
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

WORKDIR /app

# Prevent interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Install Python 3.11 and system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    poppler-utils \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Make python3.11 the default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# Upgrade pip
RUN python3 -m pip install --no-cache-dir --upgrade pip --break-system-packages

# Step 1: Install PyTorch 2.8 + torchvision 0.23 WITH CUDA from official index
# cu126 wheels work with CUDA 12.4 runtime (backwards-compatible)
RUN pip install --no-cache-dir --break-system-packages \
    torch==2.8.0 \
    torchvision==0.23.0 \
    --index-url https://download.pytorch.org/whl/cu126

# Step 2: Install chandra-ocr WITHOUT its torch/torchvision deps
RUN pip install --no-cache-dir --break-system-packages --no-deps chandra-ocr

# Step 3: Install chandra-ocr's remaining dependencies manually
RUN pip install --no-cache-dir --break-system-packages \
    runpod \
    beautifulsoup4 \
    click \
    filetype \
    flask \
    "markdownify==1.1.0" \
    openai \
    pillow \
    pydantic \
    pydantic-settings \
    pypdfium2 \
    python-dotenv \
    qwen-vl-utils \
    transformers \
    streamlit \
    accelerate

# Step 4: flash-attn for 30-50% faster inference (needs CUDA devel image)
RUN pip install --no-cache-dir --break-system-packages flash-attn

# Copy the handler
COPY handler.py /app/handler.py

# RunPod expects the handler to be the entrypoint
CMD ["python3", "-u", "/app/handler.py"]
