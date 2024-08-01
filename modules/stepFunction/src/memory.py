import json
import logging
import os
import uuid
import boto3
from botocore.exceptions import BotoCoreError
from openai import OpenAIError

from custom_methods import slack_bot_response
from models import SecretManagerCache, MissingSecretException
from pinecone_utils import get_vector_base_index
from open_ai_utils import get_embeddings

logger = logging.getLogger()
logger.setLevel(logging.INFO)
secret_manager_cache = SecretManagerCache()
WORKSPACE = os.getenv('WORKSPACE', '')


def handler(event, context):
    try:
        try:
            ai_key = secret_manager_cache.get_secret("AIKey")
            pine_cone_key = secret_manager_cache.get_secret("PineConeApiKey")
        except (BotoCoreError, MissingSecretException) as e:
            logger.error(f"Error initializing Secrets Manager client or fetching secrets: {e}")
            raise e
        logger.info(event)
        arguments = json.loads(event['arguments'])
        try:
            vector_emb = get_embeddings(arguments['memory'], ai_key)
        except OpenAIError as e:
            logger.error(f"Open AI Error: {e}")
            raise e
        id_ = str(uuid.uuid4())
        metadata = event["metadata"].copy()
        metadata.update({"memory": arguments['memory']})
        vector = {
            "id": id_,
            "values": vector_emb,
            "metadata": metadata
        }

        index = get_vector_base_index(pine_cone_key,WORKSPACE)
        index.upsert([vector])
        del vector["values"]
        create_memory(vector)
        slack_bot_response("zapamiętałem")
    except Exception as e:
        logger.error(f"Error: {e}")
        raise e


def create_memory(memory):
    boto3.resource('dynamodb').Table(WORKSPACE + '-memory').put_item(Item=memory)
