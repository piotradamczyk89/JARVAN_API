import json
import boto3
from botocore.exceptions import ClientError
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
import logging

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

dynamo = boto3.resource('dynamodb')
table = dynamo.Table('conversation')


def handler(event, context):
    try:
        response = table.scan()
        body = response['Items']
        context_string = '\n'.join([str(item['timestamp']) + ' - ' + item['memory'] for item in body])

        chat = ChatOpenAI(temperature=0.3, openai_api_key=get_secret())
        answer = chat.invoke(
            ChatPromptTemplate.from_messages([("system", system_message), ("human", human_message)]).format_prompt(
                context=context_string, question=event['arguments']['question']))
        return {"reply": answer.content}
    except KeyError as e:
        logger.error(f"Missing key in JSON data: {str(e)}")
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Missing data: {str(e)}"})
        }

    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON format: {str(e)}")
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Invalid JSON format"})
        }
    except Exception as e:
        logger.error(f"Internal Server Error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Internal server error"})
        }


def get_secret():
    secret_name = "AIKey"
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
