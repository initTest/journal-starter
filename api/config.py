import json
import os
import boto3
from dotenv import load_dotenv

def get_settings():
    # 1. First, check if we are in 'AWS' mode
    # In your k8s deployment.yaml, you will set this to 'cloud'
    env = os.getenv("APP_ENV", "local")
    region = os.getenv("region", "us-east-1")
    secret_name = os.getenv("secret_name", "journal-app-api-secrets")
    if env == "cloud":
        # 🔗 THE CLOUD PATH (AWS Secrets Manager)
        print("🚀 Running in cloud: Fetching secrets from AWS...")
        client = boto3.client('secretsmanager', region_name=region)
        response = client.get_secret_value(SecretId=secret_name)
        secrets = json.loads(response['SecretString'])
        return secrets
    else:
        # 🏠 THE LOCAL PATH (.env file)
        print("💻 Running locally: Loading .env file...")
        load_dotenv() # Load your local .env
        return {
            "DATABASE_URL": os.getenv("DATABASE_URL"),
        }