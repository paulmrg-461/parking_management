# LPR edge service (reference)

The small service that runs next to a fixed plate camera (Jetson Orin, or a CPU
box while developing). It samples RTSP frames, reads plates and posts reads to
the `device-gateway` function; the server owns every decision. See
`docs/lpr-gate.md` for the protocol, the decision table and the operator flow.

This first slice is the hardware-free core, tested with `pytest`:

| Module | Responsibility |
|---|---|
| `lpr_edge/postprocess.py` | uppercase, strip outside `A-Z0-9`, positional confusable fold, pattern check |
| `lpr_edge/config.py` | strict `lpr.yaml` (unknown keys fail), HTTPS, `0600` secrets, engine hashes |
| `lpr_edge/tracker.py` | greedy IoU tracker, one read per interval, max reads per track, best crop |
| `lpr_edge/outbox.py` | durable SQLite queue: `client_ref` before the first send, order, expiry, cap |
| `lpr_edge/gateway.py` | `seq = boot << 32 | n`, replay/skew retries, backoff, TLS verified |
| `lpr_edge/capture.py` | `FrameSource` port, OpenCV/GStreamer sources, stall detection and reconnect backoff |
| `lpr_edge/sampler.py` | idle/active cadence, motion gate, ROI crop, stale frames |
| `lpr_edge/models.py` | detector/OCR ports and fixture-driven fakes (`expected/*.json`) |
| `lpr_edge/health.py` | heartbeat payload and the inference watchdog |
| `lpr_edge/service.py` | the loop: frame → track → read → outbox → gateway, snapshot upload |
| `lpr_edge/testing.py` | the localhost fake gateway used by the integration tests and `tools/fake_gateway.py` |

The ONNX/TensorRT adapters, `__main__.py` and the recorded video fixtures are
the next slice: they depend on the owner's exact model shapes and on OpenCV/
TensorRT, which are not installed on this host. The protocol and the server
side are already complete, so those adapters only need to implement
`PlateDetector.detect` and `PlateOcr.read`.

## Install

```bash
python3 -m venv venv
./venv/bin/pip install -e '.[dev]'     # on a Jetson: -e '.[jetson]' and the system OpenCV
```

## Test

```bash
python -m pytest tests -m "not hardware and not slow"
```

The suite needs no camera, no network and no model: it covers the parsing,
permissions, queue durability (including a crash between enqueue and send),
the tracker schedule and the gateway retry classes.

## Configure

Copy `config/lpr.example.yaml` to `/etc/lpr-edge/lpr.yaml` and set the real
values:

1. Register a `camera` device in `/devices` and save the key once in
   `/etc/lpr-edge/api_key` (`0600`, owner `lpr`).
2. Assign the camera an `entry`/`exit` direction in `/gate-settings`.
3. Put the RTSP URL (credentials included) in `/etc/lpr-edge/rtsp_url`
   (`0600`) and point `capture.rtsp_url_file` at it.
4. Build the engines on the target with `tools/export_models.sh` (next slice)
   and paste their SHA-256 into `lpr.yaml`; the service refuses a mismatch.
5. Install `systemd/lpr-edge.service` and start it. Mode `assist` is the safe
   default; switch to `auto` only with a system operator configured.

## Safety

- The camera key is never logged and the RTSP URL is read from a file, never
  from `argv`.
- TLS is always verified (system CA bundle or `device.ca_file`), never
  disabled.
- A read is written to the outbox before the first send, so a crash or a
  network loss replays the same `client_ref` (the server deduplicates it).
- Reads older than the server's 15-minute window are dropped locally and
  counted in the heartbeat.
