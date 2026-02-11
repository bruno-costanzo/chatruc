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

# Install Python dependencies
# flash-attn speeds up inference 30-50% but needs the CUDA devel image (which we have)
RUN pip install --no-cache-dir \
    runpod \
    chandra-ocr \
    flash-attn \
    Pillow

# Copy the handler
COPY handler.py /app/handler.py

# RunPod expects the handler to be the entrypoint
CMD ["python3", "-u", "/app/handler.py"]
