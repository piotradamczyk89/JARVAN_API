import json
import boto3
from botocore.exceptions import ClientError
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

save_memory_schema = {
    "name": "saveMemory",
    "description": "User share an information which will be saved in database",
    "parameters": {
        "type": "object",
        "properties": {
            "memory": {
                "type": "string",
                "description": "User input",
            }
        },
        "required": [
            "memory"
        ]
    }
}
answer_question_schema = {
    "name": "answerQuestion",
    "description": "user asked a question that the chat must answer",
    "parameters": {
        "type": "object",
        "properties": {
            "question": {
                "type": "string",
                "description": "User input",
            }
        },
        "required": [
            "question"
        ]
    }
}


def handler(event, context):
    try:
        # logger.warning(event)
        # question = event['question']
        # logger.info(f"request body:\n {question}")

        # chat = ChatOpenAI(openai_api_key=get_secret(), temperature=0).bind(
        #     functions=[save_memory_schema, answer_question_schema])
        # answer = chat.invoke([HumanMessage(question)])

        # return {
        #     "statusCode": 200,
        #     "headers": {"Content-Type": "application/json"},
        #     "body": json.dumps({"reply": answer.content})
        # }
        return {"name": "saveMemory"}
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
