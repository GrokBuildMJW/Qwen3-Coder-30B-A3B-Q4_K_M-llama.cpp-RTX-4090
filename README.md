# Qwen3-Coder-30B-A3B Q4_K_M on one RTX 4090 (llama.cpp)

Serving recipe for **Qwen3-Coder-30B-A3B-Instruct** (Unsloth Q4_K_M GGUF) on one **NVIDIA GeForce RTX 4090 (24 GB)** using **llama.cpp `llama-server`**.

This repository is a **serving config for the [Ironclad AI](https://github.com/GrokBuildMJW/ironclad-ai) use case**: the local **coder** OpenAI-compatible backend. Ironclad clients call `"model": "Qwen3-Coder-30B"`. The model is instruct-only and does not emit `<think>` blocks; the pin forces `--reasoning off`.

It is a production pin plus launcher, not a training tree. The endpoint on this box is **offline** until `llama-server` is started. One GPU occupant.

Siblings (orchestrator box, DGX Spark): [Qwen3.8-Flash-Next on SGLang](https://github.com/GrokBuildMJW/Qwen3.8-Flash-Next-NVFP4-SGLang-DGX-Spark) (current) and [Qwen3.8-27B on vLLM](https://github.com/GrokBuildMJW/Qwen3.8-27B-NVFP4-vLLM-DGX-Spark) (rollback).

## Pinned stack

| Piece | Value |
|---|---|
| Target | `unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF` file `Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf` |
| SHA-256 | `fadc3e5f8d42bf7e894a785b05082e47daee4df26680389817e2093056f088ad` |
| Size | 18 556 689 568 bytes (~17.3 GiB) |
| Architecture | Qwen3 MoE, 30.5B total / **3.3B active**, 48 layers, 128 experts / 8 active, GQA 32/4, native 262 144 |
| Engine | llama.cpp `llama-server` **b10446** (`adb55e514`) |
| Topology | 1× RTX 4090 24 GB, SM 8.9, `--n-gpu-layers 99` |
| Context | **32 768** (`--ctx-size 32768`) |
| Slots | **2** (`--parallel 2`) |
| Thinking | off (`--reasoning off --no-reasoning-preserve`) |
| Chat / tools | `--jinja` (template from the GGUF) |
| Listen | `0.0.0.0:8090` |
| Served name | `Qwen3-Coder-30B` |

This is **not** the unit that was last running on the box. That one served general **Qwen3.8-27B UD-Q4_K_XL** at 32k with auto **4 slots** and `--reasoning-preserve` (~45.6 tok/s on 2026-08-24, then stopped). Fine as a chat LLM, wrong as the Ironclad coder lane. An older coder unit used this same GGUF at **8k** and `-np` default — too little context for agent file work.

32k × 2 slots fits: ~18 GB weights + ~3 GB KV for 32k on this MoE (48 layers, 4 KV heads, head_dim 128, fp16 cache) leaves headroom on 24 GB. Do not use the llama.cpp auto slot count (this build picked 4).

## Ironclad contract

| Ironclad setting | This pin |
|---|---|
| Coder model id | `Qwen3-Coder-30B` |
| Endpoint | OpenAI-compatible `:8090/v1` |
| `context_window_tokens` | `32768` |
| Concurrent slots | `2` |
| Thinking | off (the Coder instruct checkpoint never emits think tags) |
| GPU | exclusive; do not co-reside another LLM |

Clients: `http://127.0.0.1:8090/v1` with `"model": "Qwen3-Coder-30B"`.

## Serve

Build llama.cpp with CUDA (`llama-server` on `PATH`, or set `BIN`). Place the GGUF on disk, then:

```bash
MODEL=/path/to/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf bash scripts/serve.sh
```

Download (sha256 as above):

```bash
hf download unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF \
  Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf \
  --local-dir /path/to/models
```

Equivalent flags:

```bash
llama-server \
  --model /path/to/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf \
  --n-gpu-layers 99 \
  --ctx-size 32768 \
  --parallel 2 \
  --flash-attn on \
  --jinja \
  --reasoning off \
  --no-reasoning-preserve \
  --no-mmproj \
  --alias Qwen3-Coder-30B \
  --host 0.0.0.0 \
  --port 8090
```

Default bind is `0.0.0.0` because the Ironclad coder profile talks to this port on the LAN. Restrict with host firewall. Loopback-only: `HOST=127.0.0.1 bash scripts/serve.sh`.

systemd (optional, GPU occupant, do not enable a second LLM unit):

```
[Unit]
Description=llama.cpp Server (Qwen3-Coder-30B-A3B Q4, 32k)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=YOUR_USER
WorkingDirectory=/path/to/llama.cpp/build/bin
ExecStart=/path/to/llama-server --model /path/to/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf --n-gpu-layers 99 --ctx-size 32768 --parallel 2 --flash-attn on --jinja --reasoning off --no-reasoning-preserve --no-mmproj --alias Qwen3-Coder-30B --host 0.0.0.0 --port 8090
Restart=always
RestartSec=5
TimeoutStartSec=180
LimitNOFILE=65536

[Install]
WantedBy=default.target
```

## Host: Ubuntu dual-use (LLM + optional Actions runner)

This pin was taken on a workstation that also used to host a GitHub Actions listener. The two roles share one kernel and one GPU, so the OS setup is part of the recipe.

| | This box |
|---|---|
| Distro | Ubuntu **26.04 LTS** |
| Running kernel | **6.8.0-134-generic** (24.04 HWE line), GRUB-pinned |
| Distro kernels | 7.0.x installed, **not booted** |
| GPU driver | NVIDIA **580.159.03** on the 6.8 module |
| AppArmor | **off** (`apparmor=0` on cmdline; `apparmor.service` and `snapd.apparmor.service` masked) |
| Docker | Engine **29.7.2**, user in group `docker`, enabled. For CI `docker-test` / nested bwrap, not for the LLM |
| llama-server | systemd unit, **disabled** while the box is idle; enable when serving |
| Actions runner | **optional, currently absent**. Linux CI lives on a dedicated non-GPU host |

**Why the kernel pin.** 26.04 wants kernel 7.0. The 4090 driver that actually works here is 580.x on 6.8. Kernel 7.0 on this install has unused `nvidia-595-open` packages. Keep GRUB on 6.8 until you have measured a 7.0 NVIDIA stack. Same story as nested Bubblewrap in `docker-test`: unprivileged user namespaces on 6.8 are known-good.

**Why AppArmor is off.** Nested `bwrap` inside Docker (`Failed to make / slave: Permission denied`) does not survive stock `docker-default` on this distro. Do **not** put `"apparmor-profile": "unconfined"` in `/etc/docker/daemon.json` — Docker Engine 29.7.2 **rejects that key and refuses to start**. The working fix is `apparmor=0` on every GRUB linux line plus masking the units. Desktop snaps may break; this is a compute box.

**Dual-use rules**

1. **One GPU occupant.** `llama-server` with 32k and this GGUF fills the 4090. Do not schedule CUDA CI jobs against the same card while it is serving.
2. **Runner is optional.** If you put a listener back: native systemd (`actions.runner.*`), not a `restart=always` compose container. One listener. Work dir on the root disk, not on the GGUF mount.
3. **Weights off the OS disk.** Keep GGUF + llama.cpp build on a separate NVMe. Root stays free for Docker layers and runner `_work`.
4. **Do not fight Docker vs the LLM.** Docker stays installed so an optional runner can run `docker-test`. The coder process is host `llama-server`, not a GPU container.
5. **Idle box.** Leave `llama-server` disabled if the GPU is powered down or used for something else. The recipe is the flags, not a always-on daemon.

## What this is not

- Not the Qwen3.8-27B GGUF unit (general model, 4 auto slots, reasoning preserved).
- Not vLLM / SGLang / Ollama. An older Ollama `qwen2.5-coder:32b` tree on a second disk is leftover, not this pin.
- Not 256k native context. 32k is the 24 GB budget with two concurrent agent turns.
- Not a claim that llama.cpp tool calls match Spark `qwen3_coder` byte for byte. Clients should send tools on the request; `--jinja` applies the GGUF template.

## License

MIT for the scripts and notes in this tree. Model weights follow Qwen / Unsloth cards (Apache-2.0) and are not stored here.
