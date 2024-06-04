import logging
import time
import uuid
from custom_methods import slack_bot_response
from models import SecretManagerCache
import boto3
from langchain_openai import OpenAIEmbeddings
from pinecone import Pinecone, ServerlessSpec

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    secret_manager_cache = SecretManagerCache()
    ai_key = secret_manager_cache.get_secret("AIKey")
    if ai_key is None:
        logger.error("Error: AIKey could not be retrieved.")
        return None
    pine_cone_key = secret_manager_cache.get_secret("PineConeApiKey")
    if pine_cone_key is None:
        logger.error("Error: AIKey could not be retrieved.")
        return None

    model_name = "text-embedding-3-small"
    embeddings = OpenAIEmbeddings(model=model_name, openai_api_key=ai_key)

    vector_emb = embeddings.embed_query(event['arguments']['memory'])
    logger.info(vector_emb)

    id_ = str(uuid.uuid4())
    metadata = event["metadata"].copy()
    metadata.update({"memory": event['arguments']['memory']})
    vector = {
        "id": id_,
        "values": vector_emb,
        "metadata": metadata
    }

    index_name = "brain"
    pc = Pinecone(api_key=pine_cone_key)
    if index_name not in pc.list_indexes().names():
        pc.create_index(
            name=index_name,
            dimension=1536,
            metric="cosine",
            spec=ServerlessSpec(
                cloud="aws",
                region="us-east-1"
            )
        )
        while not pc.describe_index(index_name).status['ready']:
            time.sleep(1)

    index = pc.Index(index_name)
    index.upsert([vector])
    del vector["values"]
    create_memory(vector)
    slack_bot_response("zapamiętałem")


def create_memory(memory):
    boto3.resource('dynamodb').Table('memory').put_item(Item=memory)
