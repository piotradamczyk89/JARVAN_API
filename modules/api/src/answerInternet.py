import json
import boto3
from botocore.exceptions import ClientError
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
import logging
from serpapi import GoogleSearch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

system_message = """You have to answer a human question as short as possible. 
RULES $$$
- use only information from links in context to to answer questions

CONTEXT $$$
{context}
"""

human_message = "{question}"

dynamo = boto3.resource('dynamodb')
table = dynamo.Table('conversation')


def handler(event, context):
    try:
        params = {
            "q": event['arguments']['question'],
            "location": "Poland",
            "hl": "pl",
            "gl": "PL",
            "google_domain": "google.com",
            "api_key": get_secret("SerpAPI")
        }
        search = GoogleSearch(params)
        result = search.get_dict()
        result = result.get('organic_results')[0].get('link')
        # logger.warning()
        # chat = ChatOpenAI(temperature=0.3, openai_api_key=get_secret("AIKey"))
        # answer = chat.invoke(
        #     ChatPromptTemplate.from_messages([("system", system_message), ("human", human_message)]).format_prompt(
        #         context=result, question=event['arguments']['question']))
        return {"reply": result}
    except KeyError as e:
        logger.error(f"Missing key in JSON data: {str(e)}")
        return {
            "statusCode": 400,  # Bad Request
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Missing data: {str(e)}"})
        }

    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON format: {str(e)}")
        return {
            "statusCode": 400,  # Bad Request
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Invalid JSON format"})
        }
    except Exception as e:
        logger.error(f"Internal Server Error: {str(e)}")
        return {
            "statusCode": 500,  # Internal Server Error
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Internal server error"})
        }


def get_secret(secret_name):
    region_name = "eu-central-1"

    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        print(e)
        raise e

    secret = json.loads(get_secret_value_response['SecretString'])['key']
    return secret
