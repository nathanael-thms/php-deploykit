#!/usr/bin/env python3
"""
Simple webhook listener for GitHub/GitLab/Bitbucket webhooks.
Designed to work with systemd and environment variables from .env
"""
import os
import sys
import json
import hmac
import hashlib
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
import subprocess

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Load environment variables
def get_env_var(key: str, env_file: str = None) -> str:
    """Load environment variable from .env file or system environment"""
    if env_file and Path(env_file).exists():
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    k, v = line.split('=', 1)
                    if k == key:
                        # Strip quotes
                        v = v.strip('"').strip("'")
                        return v
    return os.getenv(key, '')

# Determine .env file path
script_dir = Path(__file__).parent
project_root = script_dir.parent
env_file = project_root / '.env'

# Load configuration
PORT = int(get_env_var('WEBHOOK_PORT', str(env_file)))
SECRET = get_env_var('WEBHOOK_SECRET', str(env_file))
PROVIDER = get_env_var('WEBHOOK_PROVIDER', str(env_file))
LOG_WEBHOOK = get_env_var('LOG_WEBHOOK', str(env_file)).lower() == 'true'
WEBHOOK_LOG_FILE = get_env_var('WEBHOOK_LOG_FILE', str(env_file))
GITHUB_REPORTING = get_env_var('GITHUB_REPORTING', str(env_file)).lower() == 'true'
GITHUB_TOKEN = get_env_var('GITHUB_TOKEN', str(env_file))
GITHUB_REPO_OWNER = get_env_var('GITHUB_REPO_OWNER', str(env_file))
GITHUB_REPO_NAME = get_env_var('GITHUB_REPO_NAME', str(env_file))

if LOG_WEBHOOK and WEBHOOK_LOG_FILE:
    log_path = Path(WEBHOOK_LOG_FILE)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    file_handler = logging.FileHandler(log_path)
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
    logger.addHandler(file_handler)

logger.info(f"Webhook Listener Configuration:")
logger.info(f"  Port: {PORT}")
logger.info(f"  Provider: {PROVIDER}")
logger.info(f"  Secret: {'*' * (len(SECRET) - 4) + SECRET[-4:]}")
if LOG_WEBHOOK and WEBHOOK_LOG_FILE:
    logger.info(f"  Webhook log file: {WEBHOOK_LOG_FILE}")

def send_github_status(sha: str, state: str, description: str):
    """Send deployment status to GitHub"""
    if not GITHUB_REPORTING:
        return
    
    import requests
    url = f"https://api.github.com/repos/{GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}/statuses/{sha}"
    headers = {
        'Authorization': f'token {GITHUB_TOKEN}',
        'Accept': 'application/vnd.github.v3+json'
    }
    data = {
        'state': state,
        'description': description,
        'context': 'Deployment'
    }
    try:
        response = requests.post(url, headers=headers, json=data)
        if response.status_code == 201:
            logger.info(f"GitHub status updated: {state} - {description}")
        else:
            logger.error(f"Failed to update GitHub status: {response.status_code} - {response.text}")
    except Exception as e:
        logger.error(f"Error sending GitHub status: {e}")
        
if GITHUB_REPORTING:
    logger.info(f"  GitHub reporting enabled for {GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}")
    logger.info(f"  GitHub token: {'*' * (len(GITHUB_TOKEN) - 4) + GITHUB_TOKEN[-4:]}")

class WebhookHandler(BaseHTTPRequestHandler):
    """Handle incoming webhook requests"""
    
    def do_POST(self):
        """Handle POST requests"""
        # Read request body
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8', errors='ignore')
        
        # Get signature based on provider
        sig_header = {
            'github': 'X-Hub-Signature-256',
            'gitlab': 'X-Gitlab-Token',
            'bitbucket': 'X-Gitlab-Token',
        }.get(PROVIDER, '')
        
        signature = self.headers.get(sig_header, '')
        
        logger.info(f"Received webhook: {self.path} from {self.client_address[0]}")
        
        # Verify signature
        if not self._verify_signature(body, signature):
            logger.warning(f"Invalid signature: {signature[:20]}...")
            self.send_response(401)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Invalid signature')
            return
        # Send success response
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'Webhook processed')
    
        # Process webhook
        logger.info(f"Processing webhook payload ({len(body)} bytes)")
        self._process_webhook(body)
    
    def _verify_signature(self, body: str, signature: str) -> bool:
        """Verify webhook signature based on provider"""
        if not signature:
            return False
        
        if PROVIDER == 'github':
            # GitHub: HMAC-SHA256 with sha256= prefix
            if not signature.startswith('sha256='):
                return False
            
            expected = 'sha256=' + hmac.new(
                SECRET.encode(),
                body.encode(),
                hashlib.sha256
            ).hexdigest()
            
            return hmac.compare_digest(signature, expected)
        
        elif PROVIDER in ('gitlab', 'bitbucket'):
            # GitLab/Bitbucket: Direct token comparison
            return hmac.compare_digest(signature, SECRET)
        
        return False
    
    def _process_webhook(self, body: str):
        """Process the webhook payload"""
        try:
            payload = json.loads(body)
            logger.debug(f"Payload: {json.dumps(payload, indent=2)}")
            
            commit_sha = payload.get("after")
            logger.info(f"Commit SHA: {commit_sha}")

            if commit_sha:
                send_github_status(commit_sha, "pending", "Deployment started")

            logger.info(f"Running deployment script...")
            script_path = Path(__file__).parent / '../run.sh'
            try:
                subprocess.run(['bash', str(script_path), '--deploy'], check=True)
                logger.info("Deployment script executed successfully")
                if commit_sha:
                    send_github_status(commit_sha, "success", "Deployment succeeded")
            except subprocess.CalledProcessError as e:
                logger.error(f"Deployment script failed with code {e.returncode}")
                if commit_sha:
                    send_github_status(commit_sha, "failure", "Deployment failed")
            
        except json.JSONDecodeError:
            logger.warning(f"Invalid JSON in payload")
        except Exception as e:
            logger.error(f"Error processing webhook: {e}")
    
    def log_message(self, format, *args):
        """Override to use logger instead of print"""
        logger.debug(format % args)

def main():
    """Start the webhook listener"""
    try:
        server = HTTPServer(('0.0.0.0', PORT), WebhookHandler)
        logger.info(f"Starting webhook listener on port {PORT}...")
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down webhook listener")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Failed to start listener: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
