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
PORT = int(get_env_var('WEBHOOK_PORT', str(env_file)) or 8080)
SECRET = get_env_var('WEBHOOK_SECRET', str(env_file)) or 'your_webhook_secret'
PROVIDER = get_env_var('WEBHOOK_PROVIDER', str(env_file)) or 'github'

logger.info(f"Webhook Listener Configuration:")
logger.info(f"  Port: {PORT}")
logger.info(f"  Provider: {PROVIDER}")
logger.info(f"  Secret: {'*' * (len(SECRET) - 4) + SECRET[-4:]}")

class WebhookHandler(BaseHTTPRequestHandler):
    """Handle incoming webhook requests"""
    
    def do_POST(self):
        """Handle POST requests"""
        # Read request body
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8', errors='ignore')
        
        # Get headers
        referer = self.headers.get('Referer', '')
        
        # Get signature based on provider
        sig_header = {
            'github': 'X-Hub-Signature-256',
            'gitlab': 'X-Gitlab-Token',
            'bitbucket': 'X-Gitlab-Token',
        }.get(PROVIDER, '')
        
        signature = self.headers.get(sig_header, '')
        
        logger.info(f"Received webhook: {self.path} from {self.client_address[0]}")
        
        # Verify request source (referer check)
        if not self._verify_request(referer):
            logger.warning(f"Invalid source: {referer}")
            self.send_response(403)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Invalid source')
            return
        
        # Verify signature
        if not self._verify_signature(body, signature):
            logger.warning(f"Invalid signature: {signature[:20]}...")
            self.send_response(401)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Invalid signature')
            return
        
        # Process webhook
        logger.info(f"Processing webhook payload ({len(body)} bytes)")
        self._process_webhook(body)
        
        # Send success response
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'Webhook processed')
    
    def _verify_request(self, referer: str) -> bool:
        """Verify request source based on provider"""
        if not referer:
            return False
        
        provider_hosts = {
            'github': 'github.com',
            'gitlab': 'gitlab.com',
            'bitbucket': 'bitbucket.org',
        }
        
        expected_host = provider_hosts.get(PROVIDER, '')
        return expected_host in referer if expected_host else False
    
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
            
            # Add processing logic here
            # Example: trigger deployment based on event
            # if payload.get('action') == 'push':
            #     logger.info("Push event detected, triggering deployment...")
            #     # subprocess.run([...deploy...])
            logger.info(f"Running deployment script...")
            script_path = project_root.parent / 'run.sh'
            try:
                subprocess.run(['bash', str(script_path)], check=True)
                logger.info("Deployment script executed successfully")
            except subprocess.CalledProcessError as e:
                logger.error(f"Deployment script failed with code {e.returncode}")
            
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
