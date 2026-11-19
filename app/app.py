import os
import platform
import flask
import requests
import yaml
from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(
        {
            "service": "zeroday-aitd-demo-app",
            "status": "running",
            "environment": os.getenv("APP_ENV", "sandbox"),
            "python_version": platform.python_version(),
        }
    )


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


@app.route("/inventory")
def inventory():
    return jsonify(
        {
            "packages": {
                "flask": flask.__version__,
                "requests": requests.__version__,
                "pyyaml": yaml.__version__,
            }
        }
    ), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)