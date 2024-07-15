import json

import boto3
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
import logging
from models import SecretManagerCache
from custom_methods import slack_bot_response
from pinecone_utils import get_vector_base_index
from open_ai_utils import get_embeddings

logger = logging.getLogger()
logger.setLevel(logging.INFO)

system_message = """You have to answer a human question as short as possible. 
RULES $$$
- use only data in context to answer questions
- IMPORTANT each data in context  will have a timestamp. If two or more information can give the answer for the question use this one with bigger timestamp
- if context do not have necessary information only in this kind of scenario use your own knowledge

CONTEXT $$$
{context}
"""

human_message = "{question}"

dynamodb = boto3.client('dynamodb')


def handler(event, context):
    secret_manager_cache = SecretManagerCache()
    ai_key = secret_manager_cache.get_secret("AIKey")
    pine_cone_key = secret_manager_cache.get_secret("PineConeApiKey")
    arguments = json.loads(event['arguments'])
    vector_emb = get_embeddings(arguments['question'], ai_key)
    index = get_vector_base_index(pine_cone_key)

    response = index.query(vector=vector_emb, top_k=3, include_values=False)
    record_ids = [vector["id"] for vector in response["matches"]]
    context_string = "\n".join([item['metadata']['M']['memory']['S'] for item in get_memories(record_ids)])
    logger.info(context_string)
    chat = ChatOpenAI(temperature=0.3, openai_api_key=ai_key)
    answer = chat.invoke(
        ChatPromptTemplate.from_messages([("system", system_message), ("human", human_message)]).format_prompt(
            context=context_string, question=arguments['question']))
    slack_bot_response(answer.content)


def get_memories(record_ids: list):
    keys = [{'id': {'S': str(id_)}} for id_ in record_ids]
    request_items = {"memory": {'Keys': keys}}
    response = dynamodb.batch_get_item(RequestItems=request_items)
    items = response.get('Responses', {}).get("memory", [])
    logger.info(items)
    return items
