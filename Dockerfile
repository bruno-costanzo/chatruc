# =============================================================================
# Dockerfile for Chandra OCR on RunPod Serverless
# =============================================================================
# We use a minimal CUDA devel image instead of RunPod's PyTorch image
# because chandra-ocr requires torch>=2.8.0 and the RunPod image ships 2.4.0.
# =============================================================================

FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive

# Install Python 3.11 and system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    poppler-utils \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Make python3.11 the default and install pip
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# Step 1: Install PyTorch 2.8 + torchvision 0.23 WITH CUDA
RUN pip install --no-cache-dir \
    torch==2.8.0 \
    torchvision==0.23.0 \
    --index-url https://download.pytorch.org/whl/cu126

# Step 2: Install chandra-ocr + runpod, pinning torch so pip won't touch it
RUN echo "torch==2.8.0" > /tmp/constraints.txt && \
    echo "torchvision==0.23.0" >> /tmp/constraints.txt && \
    pip install --no-cache-dir -c /tmp/constraints.txt \
    chandra-ocr \
    runpod

# Step 3: flash-attn for 30-50% faster inference
RUN pip install --no-cache-dir flash-attn

# Copy the handler
COPY handler.py /app/handler.py

CMD ["python3", "-u", "/app/handler.py"]
