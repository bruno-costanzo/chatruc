"""
RunPod Serverless Handler for Chandra OCR
==========================================
Loads the Chandra model ONCE at startup (from RunPod's model cache),
then processes incoming PDF pages / images and returns markdown + metadata.

Input format:
{
    "input": {
        "image_base64": "<base64-encoded image or PDF page>",
        "prompt_type": "ocr_layout"  // optional, default: "ocr_layout"
    }
}

Output format:
{
    "markdown": "...",
    "html": "...",
    "raw": "..."
}
"""

import os
import base64
import io
import runpod
from PIL import Image

# ---------------------------------------------------------------------------
# 1. MODEL LOADING — happens once at cold start, NOT per request
#    The model is cached at /runpod-volume/huggingface-cache/hub/
#    thanks to RunPod's Model Caching feature.
# ---------------------------------------------------------------------------

# These can be set via RunPod UI (Environment Variables) or fallback to defaults.
# The key ones prevent HuggingFace from downloading anything at runtime.
os.environ.setdefault("HF_HOME", "/runpod-volume/huggingface-cache/hub")
os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

MODEL_NAME = os.environ.get("MODEL_CHECKPOINT", "datalab-to/chandra")

print(f"[Chandra] Loading model: {MODEL_NAME}")

from transformers import AutoModel, AutoProcessor
from chandra.model.hf import generate_hf
from chandra.model.schema import BatchInputItem
from chandra.output import parse_markdown

# Load model + processor into GPU memory (happens once)
model = AutoModel.from_pretrained(
    MODEL_NAME,
    trust_remote_code=True,
).cuda()

model.processor = AutoProcessor.from_pretrained(
    MODEL_NAME,
    trust_remote_code=True,
)

print("[Chandra] Model loaded successfully!")


# ---------------------------------------------------------------------------
# 2. HANDLER — processes each incoming request
# ---------------------------------------------------------------------------

def handler(event):
    """
    Receives a base64-encoded image (or PDF page rendered as image),
    runs Chandra OCR, and returns markdown + raw output.
    """
    try:
        input_data = event["input"]

        # Decode the base64 image
        image_b64 = input_data.get("image_base64")
        if not image_b64:
            return {"error": "Missing 'image_base64' in input"}

        image_bytes = base64.b64decode(image_b64)
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

        # Which prompt type to use (ocr_layout is the default and best for PDFs)
        prompt_type = input_data.get("prompt_type", "ocr_layout")

        # Build the batch (single image)
        batch = [
            BatchInputItem(
                image=image,
                prompt_type=prompt_type,
            )
        ]

        # Run inference
        result = generate_hf(batch, model)[0]

        # Parse the raw output into clean markdown
        markdown = parse_markdown(result.raw)

        return {
            "markdown": markdown,
            "raw": result.raw,
        }

    except Exception as e:
        return {"error": str(e)}


# ---------------------------------------------------------------------------
# 3. START — register the handler with RunPod
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
