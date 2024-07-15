import json
from openai import OpenAIError
import boto3
from botocore.exceptions import BotoCoreError
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
import logging
from models import SecretManagerCache, MissingSecretException
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
    try:
        try:
            secret_manager_cache = SecretManagerCache()
            ai_key = secret_manager_cache.get_secret("AIKey")
            pine_cone_key = secret_manager_cache.get_secret("PineConeApiKey")
        except (BotoCoreError, MissingSecretException) as e:
            logger.error(f"Error initializing Secrets Manager client or fetching secrets: {e}")
            raise e

        try:
            arguments = json.loads(event['arguments'])
            vector_emb = get_embeddings(arguments['question'], ai_key)
        except OpenAIError as e:
            logger.error(f"OpenAIError during embedding {e}")
            raise e

        index = get_vector_base_index(pine_cone_key)
        response = index.query(vector=vector_emb, top_k=3, include_values=False)
        record_ids = [vector["id"] for vector in response["matches"]]
        context_string = "\n".join([item['metadata']['M']['memory']['S'] for item in get_memories(record_ids)])
        logger.info(context_string)
        chat = ChatOpenAI(temperature=0.3, openai_api_key=ai_key)
        try:
            answer = chat.invoke(
                ChatPromptTemplate.from_messages([("system", system_message), ("human", human_message)]).format_prompt(
                    context=context_string, question=arguments['question']))
        except OpenAIError as e:
            logger.error(f"OpenAIError during chat invocation: {e}")
            raise e
        slack_bot_response(answer.content)
    except Exception as e:
        logger.error(f"Error: {e}")
        raise e


def get_memories(record_ids: list):
    keys = [{'id': {'S': str(id_)}} for id_ in record_ids]
    request_items = {"memory": {'Keys': keys}}
    response = dynamodb.batch_get_item(RequestItems=request_items)
    items = response.get('Responses', {}).get("memory", [])
    logger.info(items)
    return items
