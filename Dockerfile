# =============================================================================
# Dockerfile for Chandra OCR on RunPod Serverless
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

# Step 2: Install chandra-ocr without pulling its own torch/torchvision
RUN pip install --no-cache-dir --no-deps chandra-ocr

# Step 3: Install remaining chandra-ocr deps one by one
# (split so we can see exactly which one fails in build logs)
RUN pip install --no-cache-dir "beautifulsoup4>=4.14.2"
RUN pip install --no-cache-dir "click>=8.0.0"
RUN pip install --no-cache-dir "filetype>=1.2.0"
RUN pip install --no-cache-dir "flask>=3.0.0"
RUN pip install --no-cache-dir "markdownify==1.1.0"
RUN pip install --no-cache-dir "openai>=2.2.0"
RUN pip install --no-cache-dir "pillow>=10.2.0"
RUN pip install --no-cache-dir "pydantic>=2.12.0"
RUN pip install --no-cache-dir "pydantic-settings>=2.11.0"
RUN pip install --no-cache-dir "pypdfium2>=4.30.0"
RUN pip install --no-cache-dir "python-dotenv>=1.1.1"
RUN pip install --no-cache-dir "qwen-vl-utils>=0.0.14"
RUN pip install --no-cache-dir "transformers>=4.57.1"
RUN pip install --no-cache-dir "streamlit>=1.50.0"
RUN pip install --no-cache-dir "accelerate>=1.11.0"
RUN pip install --no-cache-dir runpod

# Step 4: flash-attn for faster inference
RUN pip install --no-cache-dir flash-attn

# Copy the handler
COPY handler.py /app/handler.py

CMD ["python3", "-u", "/app/handler.py"]
