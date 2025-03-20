#!/usr/bin/env python3

from flask import Flask, request, jsonify, render_template_string
import subprocess
import os

app = Flask(__name__)

SECRET_TOKEN = os.getenv("SECRET_TOKEN", "default_token")  # systemd service will set this
ENV_FILE = "./.env"

@app.route('/webhook', methods=['POST'])
def webhook():
    auth_header = request.headers.get("Authorization")
    if not auth_header or auth_header != f"Bearer {SECRET_TOKEN}":
        return jsonify({"error": "Unauthorized"}), 403
    
    data = request.json
    image = data.get("image")
    service_name = data.get("service")
    
    if not image or not service_name:
        return jsonify({"error": "Image or service not provided"}), 400

    try:
        # Extract the tag from the image
        tag = image.split(":")[-1]

        # Update .env file with the new tag
        with open(ENV_FILE, "r") as f:
            lines = f.readlines()
        with open(ENV_FILE, "w") as f:
            for line in lines:
                if line.startswith(f"{service_name.upper()}_TAG="):
                    f.write(f"{service_name.upper()}_TAG={tag}\n")
                else:
                    f.write(line)

        # Reload the updated environment variables from .env
        # Due to some issue with environment variables (otherwise reloaded with old tags)
        env = os.environ.copy()
        with open(ENV_FILE, "r") as f:
            for line in f:
                if "=" in line:
                    key, value = line.strip().split("=", 1)
                    env[key] = value

        # Pull the new image
        subprocess.run(["docker", "pull", image], check=True)

        # Stop and remove existing containers
        subprocess.run(["docker-compose", "down", "--volumes", "--remove-orphans", "--timeout", "30"], check=True)

        # Restart all services with the updated environment
        subprocess.run([
            "docker-compose", 
            "up", 
            "--force-recreate", 
            "--renew-anon-volumes", 
            "-d"
        ], check=True, env=env)

        return jsonify({"message": "Deployment successful"}), 200
    except subprocess.CalledProcessError as e:
        return jsonify({"error": f"Deployment failed: {e.stderr}"}), 500
    except Exception as e:
        return jsonify({"error": f"Deployment failed: {str(e)}"}), 500

@app.route('/')
def show_tags():
    """Display current tags for all services."""
    try:
        with open(ENV_FILE, "r") as f:
            env_lines = f.readlines()
        tags = {line.split("=")[0]: line.split("=")[1].strip() for line in env_lines if "=" in line}
        html_template = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Service Tags</title>
        </head>
        <body>
            <h1>Current Service Tags</h1>
            <table border="1">
                <tr><th>Service</th><th>Tag</th></tr>
                {% for service, tag in tags.items() %}
                <tr><td>{{ service }}</td><td>{{ tag }}</td></tr>
                {% endfor %}
            </table>
        </body>
        </html>
        """
        return render_template_string(html_template, tags=tags)
    except Exception as e:
        return f"Error reading tags: {str(e)}", 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
