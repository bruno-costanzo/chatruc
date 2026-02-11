FROM registry.runpod.net/runpod-workers-worker-vllm-main-dockerfile:6d6cbe709
RUN pip install "transformers<4.57.7" --break-system-packages
