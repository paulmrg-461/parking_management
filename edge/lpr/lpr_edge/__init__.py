"""Reference LPR edge service: post-processing, tracking, the local outbox and
the gateway client. The capture/detector/OCR adapters live in their own
modules and are only imported when the service runs."""

__all__ = ["config", "gateway", "outbox", "postprocess", "tracker"]
