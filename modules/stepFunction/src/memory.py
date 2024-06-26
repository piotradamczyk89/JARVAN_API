import logging
import uuid
import boto3
from custom_methods import slack_bot_response
from models import SecretManagerCache
from pinecone_utils import get_vector_base_index
from open_ai_utils import get_embeddings

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
        secret_manager_cache = SecretManagerCache()
        ai_key = secret_manager_cache.get_secret("AIKey")
        pine_cone_key = secret_manager_cache.get_secret("PineConeApiKey")

        vector_emb = get_embeddings(event['arguments']['memory'], ai_key)
        id_ = str(uuid.uuid4())
        metadata = event["metadata"].copy()
        metadata.update({"memory": event['arguments']['memory']})
        vector = {
            "id": id_,
            "values": vector_emb,
            "metadata": metadata
        }
        index = get_vector_base_index(pine_cone_key)
        index.upsert([vector])
        del vector["values"]
        create_memory(vector)
        slack_bot_response("zapamiętałem")


def create_memory(memory):
    boto3.resource('dynamodb').Table('memory').put_item(Item=memory)
