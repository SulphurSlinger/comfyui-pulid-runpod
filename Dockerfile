# syntax=docker/dockerfile:1.7
FROM runpod/worker-comfyui:5.10.0-base

LABEL org.opencontainers.image.source="https://github.com/OWNER/REPO"

# Custom nodes
RUN comfy node install --exit-on-fail comfyui_pulid_flux_ll --mode remote
RUN comfy node install --exit-on-fail comfyui_patches_ll

# PuLID dependencies proven working in the tested RunPod environment.
# Keep headless OpenCV and GPU ONNX Runtime instead of installing the CPU/GUI variants.
RUN /opt/venv/bin/python -m pip install --no-cache-dir \
      opencv-python-headless==5.0.0.93 \
      cython==3.3.0 \
      ftfy==6.3.1 \
      timm==1.0.30 \
      onnx==1.23.2 \
      filterpy==1.4.5 \
      numba==0.68.0 \
      flatbuffers==25.12.19 \
      protobuf==7.36.2 \
      scikit-image==0.26.0 \
      ml-dtypes==0.6.0 && \
    /opt/venv/bin/python -m pip install --no-cache-dir --no-deps \
      facexlib==0.3.0 \
      insightface==2.1 && \
    (/opt/venv/bin/python -m pip uninstall -y onnxruntime onnxruntime-gpu || true)

RUN /opt/venv/bin/python -m pip install --no-cache-dir --no-deps \
      onnxruntime-gpu==1.26.0

# Sanity check the stack that failed in the original Wizard image.
RUN /opt/venv/bin/python - <<'PY'
import cv2
import onnx
import insightface
import facexlib
import onnxruntime as ort

print("cv2:", cv2.__version__)
print("onnx:", onnx.__version__)
print("insightface:", insightface.__version__)
print("facexlib:", facexlib.__version__)
print("onnxruntime:", ort.__version__)
PY

# Compatibility patch for ComfyUI 0.34+ passing latent_shapes and other kwargs
# through the PuLID outer sampler wrapper. Safe if upstream already contains it.
RUN cd /comfyui/custom_nodes/comfyui_pulid_flux_ll && \
    /opt/venv/bin/python - <<'PY'
from pathlib import Path

p = Path("pulidflux.py")
s = p.read_text()

old_sig1 = (
    "def pulid_outer_sample_wrappers_with_override("
    "wrapper_executor, noise, latent_image, sampler, sigmas, "
    "denoise_mask=None, callback=None, disable_pbar=False, seed=None):"
)
new_sig1 = (
    "def pulid_outer_sample_wrappers_with_override("
    "wrapper_executor, noise, latent_image, sampler, sigmas, "
    "denoise_mask=None, callback=None, disable_pbar=False, seed=None, **kwargs):"
)

old_sig2 = (
    "def pulid_outer_sample_wrappers("
    "wrapper_executor, noise, latent_image, sampler, sigmas, "
    "denoise_mask=None, callback=None, disable_pbar=False, seed=None):"
)
new_sig2 = (
    "def pulid_outer_sample_wrappers("
    "wrapper_executor, noise, latent_image, sampler, sigmas, "
    "denoise_mask=None, callback=None, disable_pbar=False, seed=None, **kwargs):"
)

old_call = (
    "out = wrapper_executor(noise, latent_image, sampler, sigmas, "
    "denoise_mask, callback, disable_pbar, seed)"
)
new_call = (
    "out = wrapper_executor(noise, latent_image, sampler, sigmas, "
    "denoise_mask, callback, disable_pbar, seed, **kwargs)"
)

old_counts = (s.count(old_sig1), s.count(old_sig2), s.count(old_call))
new_counts = (s.count(new_sig1), s.count(new_sig2), s.count(new_call))

if new_counts == (1, 1, 2):
    print("PuLID sampler wrappers already support **kwargs; no patch needed.")
elif old_counts == (1, 1, 2):
    s = s.replace(old_sig1, new_sig1)
    s = s.replace(old_sig2, new_sig2)
    s = s.replace(old_call, new_call)
    p.write_text(s)
    print("Applied PuLID sampler compatibility patch.")
else:
    raise SystemExit(
        "Unexpected PuLID wrapper source; refusing blind patch. "
        f"old_counts={old_counts}, new_counts={new_counts}"
    )
PY

RUN /opt/venv/bin/python -m py_compile \
      /comfyui/custom_nodes/comfyui_pulid_flux_ll/pulidflux.py

COPY start-gui.sh /usr/local/bin/start-gui.sh
RUN chmod +x /usr/local/bin/start-gui.sh

EXPOSE 8188
ENTRYPOINT []
CMD ["/usr/local/bin/start-gui.sh"]
