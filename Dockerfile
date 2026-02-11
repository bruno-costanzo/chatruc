# =============================================================================
# Dockerfile for Chandra OCR on RunPod Serverless
# =============================================================================
# Base image: RunPod's PyTorch image with CUDA support
# This gives us: Python 3.11, PyTorch, CUDA 12.4, and common ML deps
# =============================================================================

FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

WORKDIR /app

# Install system dependencies for PDF processing and image handling
RUN apt-get update && apt-get install -y --no-install-recommends \
    poppler-utils \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Fix: blinker is pre-installed as a distutils package in the base image
# and conflicts with newer versions. Force-reinstall it first.
RUN pip install --no-cache-dir --force-reinstall blinker

# Install chandra-ocr first, then fix torch/torchvision compatibility
# The base image has PyTorch pre-installed but chandra-ocr may pull
# an incompatible torchvision version.
RUN pip install --no-cache-dir \
    runpod \
    chandra-ocr \
    Pillow

# Reinstall torchvision matching the base image's PyTorch version
RUN pip install --no-cache-dir --force-reinstall torchvision --index-url https://download.pytorch.org/whl/cu124

# flash-attn for 30-50% faster inference (optional but recommended)
RUN pip install --no-cache-dir flash-attn

# Copy the handler
COPY handler.py /app/handler.py

# RunPod expects the handler to be the entrypoint
CMD ["python3", "-u", "/app/handler.py"]
