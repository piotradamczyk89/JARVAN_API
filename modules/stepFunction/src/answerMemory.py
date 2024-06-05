import json
import boto3
from botocore.exceptions import ClientError
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
import logging
from models import SecretManagerCache
from pinecone import Pinecone
from custom_methods import slack_bot_response

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
        secret_manager_cache = SecretManagerCache()
        ai_key = secret_manager_cache.get_secret("AIKey")
        pine_cone_key = secret_manager_cache.get_secret("PineConeApiKey")

        vector_emb = get_embeddings(event['arguments']['question'], ai_key)

        index_name = "brain"
        pc = Pinecone(api_key=pine_cone_key)
        index = pc.Index(index_name)
        response = index.query(vector=vector_emb, top_k=3, include_values=True)
        record_ids = [vector["id"] for vector in response["matches"]]
        logger.info("ids:")
        logger.info(record_ids)
        context_string = "\n".join([item['metadata']['M']['text']['S'] for item in get_memories(record_ids)])

        chat = ChatOpenAI(temperature=0.3, openai_api_key=ai_key)
        answer = chat.invoke(
            ChatPromptTemplate.from_messages([("system", system_message), ("human", human_message)]).format_prompt(
                context=context_string, question=event['arguments']['question']))
        slack_bot_response(answer.content)
    except KeyError as e:
        logger.error(f"Missing key in JSON data: {str(e)}")
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Missing data: {str(e)}"})
        }
    except ClientError as e:
        logger.error(f"Missing key in JSON data: {str(e)}")
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Missing data: {str(e)}"})
        }


def get_memories(record_ids: list):
    keys = [{'id': {'S': str(id_)}} for id_ in record_ids]
    request_items = {"memory": {'Keys': keys}}
    try:
        response = dynamodb.batch_get_item(RequestItems=request_items)
        items = response.get('Responses', {}).get("memory", [])
        logger.info(items)
        return items
    except Exception as e:
        logger.error(str(e))
        return None
