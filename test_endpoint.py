"""
Test script to send a PDF page to your Chandra OCR RunPod endpoint.

Usage:
    export RUNPOD_API_KEY="your-api-key"
    export RUNPOD_ENDPOINT_ID="your-endpoint-id"
    python test_endpoint.py path/to/image.png

For PDFs, you need to convert pages to images first.
This script includes a helper for that.
"""

import os
import sys
import base64
import time
import requests


API_KEY = os.environ.get("RUNPOD_API_KEY")
ENDPOINT_ID = os.environ.get("RUNPOD_ENDPOINT_ID")
BASE_URL = f"https://api.runpod.ai/v2/{ENDPOINT_ID}"


def image_to_base64(path: str) -> str:
    """Read an image file and return base64 string."""
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def pdf_to_images(pdf_path: str) -> list[str]:
    """
    Convert PDF pages to base64-encoded images.
    Requires: pip install pdf2image
    And system: apt-get install poppler-utils
    """
    from pdf2image import convert_from_path

    images = convert_from_path(pdf_path, dpi=300)
    result = []
    for img in images:
        import io
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        b64 = base64.b64encode(buffer.getvalue()).decode("utf-8")
        result.append(b64)
    return result


def send_request(image_b64: str) -> dict:
    """Send async request to RunPod endpoint."""
    response = requests.post(
        f"{BASE_URL}/run",
        headers={"Authorization": f"Bearer {API_KEY}"},
        json={
            "input": {
                "image_base64": image_b64,
                "prompt_type": "ocr_layout",
            }
        },
    )
    response.raise_for_status()
    return response.json()


def poll_result(task_id: str, timeout: int = 120) -> dict:
    """Poll for async result until done or timeout."""
    start = time.time()
    while time.time() - start < timeout:
        response = requests.get(
            f"{BASE_URL}/status/{task_id}",
            headers={"Authorization": f"Bearer {API_KEY}"},
        )
        data = response.json()

        status = data.get("status")
        if status == "COMPLETED":
            return data["output"]
        elif status == "FAILED":
            print(f"Job failed: {data}")
            sys.exit(1)

        print(f"  Status: {status}... waiting 2s")
        time.sleep(2)

    print("Timeout waiting for result")
    sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_endpoint.py <image_or_pdf_path>")
        sys.exit(1)

    if not API_KEY or not ENDPOINT_ID:
        print("Set RUNPOD_API_KEY and RUNPOD_ENDPOINT_ID env vars")
        sys.exit(1)

    file_path = sys.argv[1]

    # Handle PDF vs image
    if file_path.lower().endswith(".pdf"):
        print(f"Converting PDF to images: {file_path}")
        pages = pdf_to_images(file_path)
        print(f"Found {len(pages)} pages")
    else:
        pages = [image_to_base64(file_path)]

    # Process each page
    for i, page_b64 in enumerate(pages):
        print(f"\n--- Page {i + 1} ---")
        print("Sending request...")

        result = send_request(page_b64)
        task_id = result["id"]
        print(f"Task ID: {task_id}")

        output = poll_result(task_id)

        if "error" in output:
            print(f"Error: {output['error']}")
        else:
            print(f"\nMarkdown output:\n{output['markdown']}")
