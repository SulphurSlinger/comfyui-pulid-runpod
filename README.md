# RunPod ComfyUI PuLID GUI

A reproducible GUI-mode ComfyUI image for RunPod Pods.

## What is baked into the image
- RunPod `worker-comfyui:5.10.0-base`
- `comfyui_pulid_flux_ll`
- `comfyui_patches_ll`
- Tested PuLID Python dependencies
- GPU ONNX Runtime 1.26.0
- PuLID sampler wrapper compatibility patch for newer ComfyUI

## What lives on the RunPod network volume
Mount a network volume at `/workspace`.

The startup script persists:
- `/workspace/models`
- `/workspace/comfyui/input`
- `/workspace/comfyui/output`
- `/workspace/comfyui/user`

Large FLUX and PuLID weights are downloaded once into the volume on first boot.
EVA-CLIP, InsightFace AntelopeV2, and facexlib assets are downloaded on first PuLID use and then persist there as well.

## RunPod
Expose HTTP port `8188`.
Use the GHCR image produced by GitHub Actions:
`ghcr.io/<github-user>/<repo>:latest`
