#!/usr/bin/env bash
set -euo pipefail

# /workspace should be a RunPod network volume in the permanent deployment.
mkdir -p \
  /workspace/models/checkpoints \
  /workspace/models/diffusion_models \
  /workspace/models/pulid \
  /workspace/comfyui/input \
  /workspace/comfyui/output \
  /workspace/comfyui/user

# Persist models, uploaded inputs, saved outputs, and ComfyUI user/workflow data.
rm -rf /comfyui/models /comfyui/input /comfyui/output /comfyui/user
ln -s /workspace/models /comfyui/models
ln -s /workspace/comfyui/input /comfyui/input
ln -s /workspace/comfyui/output /comfyui/output
ln -s /workspace/comfyui/user /comfyui/user

cd /comfyui

# Download the large core models once into the persistent volume.
if [ ! -f models/checkpoints/flux1-dev-fp8.safetensors ]; then
  echo "Downloading FLUX.1-dev fp8 checkpoint to persistent storage..."
  comfy model download \
    --url 'https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors' \
    --relative-path models/checkpoints \
    --filename 'flux1-dev-fp8.safetensors'
fi

if [ ! -f models/diffusion_models/pulid_flux_v0.9.1.safetensors ]; then
  echo "Downloading PuLID Flux model to persistent storage..."
  comfy model download \
    --url 'https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors' \
    --relative-path models/diffusion_models \
    --filename 'pulid_flux_v0.9.1.safetensors'
fi

ln -sfn \
  /workspace/models/diffusion_models/pulid_flux_v0.9.1.safetensors \
  /workspace/models/pulid/pulid_flux_v0.9.1.safetensors

# EVA-CLIP, InsightFace AntelopeV2, and facexlib assets are downloaded by
# PuLID on first use. Because /comfyui/models points at /workspace/models,
# those downloads persist too.

exec /opt/venv/bin/python /comfyui/main.py --listen 0.0.0.0 --port 8188
