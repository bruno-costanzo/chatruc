# Chandra OCR — RunPod Serverless

Deploy [Chandra OCR](https://github.com/datalab-to/chandra) (9B param model by Datalab) on RunPod Serverless with model caching (no re-downloads on cold start).

## Architecture

```
Client → RunPod API → Worker (GPU 48GB)
                        ├── Model loaded from cache (/runpod-volume/)
                        ├── Chandra OCR inference (HuggingFace method)
                        └── Returns markdown + raw output
```

## Step-by-Step Deployment

### 1. Build and push the Docker image

```bash
# Build
docker build -t your-dockerhub-user/chandra-runpod:latest .

# Push to Docker Hub (or any registry RunPod can access)
docker push your-dockerhub-user/chandra-runpod:latest
```

> **Tip:** flash-attn compilation takes a while (~10-15 min). Be patient.

### 2. Create a Serverless Endpoint in RunPod

1. Go to [RunPod Console → Serverless](https://www.runpod.io/console/serverless)
2. Click **New Endpoint**
3. Configure:

| Setting              | Value                                       |
|----------------------|---------------------------------------------|
| **Container Image**  | `your-dockerhub-user/chandra-runpod:latest` |
| **Model**            | `datalab-to/chandra`                        |
| **GPU Type**         | 48 GB (A6000 or similar)                    |
| **Container Disk**   | 20 GB minimum                               |
| **Idle Timeout**     | 30-60s (keep warm between requests)         |
| **Active Workers**   | 0 (scale to zero when idle)                 |
| **Max Workers**      | 1-3 (depending on your throughput needs)    |

The **Model** field is the key — RunPod will automatically cache `datalab-to/chandra` at `/runpod-volume/huggingface-cache/hub/` so the handler can load it in offline mode without downloading.

### 3. Test your endpoint

```bash
# Set your credentials
export RUNPOD_API_KEY="your-api-key-here"
export RUNPOD_ENDPOINT_ID="your-endpoint-id-here"

# Install test dependencies
pip install requests pdf2image

# Test with an image
python test_endpoint.py document_page.png

# Test with a PDF (converts pages to images automatically)
python test_endpoint.py document.pdf
```

## How it works

1. **Cold start:** RunPod spins up a worker → Docker container starts → handler.py loads model from `/runpod-volume/huggingface-cache/` into GPU memory. This takes ~30-60s the first time.

2. **Warm request:** Model is already in GPU memory → base64 image comes in → Chandra processes it → returns markdown in ~1-2s per page.

3. **Scale to zero:** After idle timeout, worker shuts down. No charges while idle.

4. **Next request:** Cold start again, but model loads from local cache (no HuggingFace download).

## Environment Variables

| Variable               | Default               | Description                          |
|------------------------|-----------------------|--------------------------------------|
| `MODEL_CHECKPOINT`     | `datalab-to/chandra`  | HuggingFace model to load            |
| `HF_HOME`              | (set by handler)      | Path to HF cache                     |
| `HF_HUB_OFFLINE`       | `1`                   | Prevent network calls to HF          |

## Troubleshooting

**"Model not found" error on startup:**
Make sure the **Model** field in your endpoint config is set to `datalab-to/chandra`. Check logs for `[ModelStore] Using snapshot` to confirm caching is working.

**Cold start too slow (>2 min):**
Set `Active Workers: 1` to keep one worker always warm. This costs ~$0.50/hr but eliminates cold starts.

**Out of memory:**
Make sure you selected a 48GB GPU. The 9B model in BF16 needs ~18GB VRAM plus overhead for inference.

## Cost Estimate

- **Per request (warm):** ~1-2 seconds GPU time ≈ $0.001-0.002
- **Cold start overhead:** ~30-60s additional
- **Idle:** $0 (with Active Workers = 0)
- **Always-warm worker:** ~$0.50-0.76/hr depending on GPU type

## License

Your code (handler, test script): MIT.
Chandra model weights: [Modified OpenRAIL-M](https://github.com/datalab-to/chandra) — free for research, personal use, and startups under $2M funding/revenue.
