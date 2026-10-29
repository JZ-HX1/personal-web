"""Consistent UTF-8 output for command-line entry points on every platform."""
import sys


def configure_utf8_output():
    """Keep Chinese JSON and help readable, including redirected Windows output."""
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if callable(reconfigure):
            reconfigure(encoding="utf-8")
