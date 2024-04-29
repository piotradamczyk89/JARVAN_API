import json
import boto3
from botocore.exceptions import ClientError
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    try:
        event = json.loads(event["body"])
        question = event['question']
        logger.info(f"request body:\n {question}")

        system_message = SystemMessage("answer user question as short as possible")
        human_message = HumanMessage(question)
        chat = ChatOpenAI(openai_api_key=get_secret())
        answer = chat.invoke(
            ChatPromptTemplate.from_messages([system_message, human_message]).format_prompt())

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"reply": answer.content})
        }
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


def get_secret():
    secret_name = "openAIKey"
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
