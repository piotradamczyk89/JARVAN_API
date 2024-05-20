import json
import logging
import boto3
from botocore.exceptions import ClientError
from langchain_core.messages import HumanMessage
from langchain_openai import ChatOpenAI

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
answer_memory_schema = {
    "name": "answerMemoryQuestion",
    "description": """the user asks a question which indicates that he wants to refer to the jointly created memory of the model and his own.
     The question may concern his life, the life of his loved ones, his notes, or information he wrote down in shared memory. Examples of statements are:
- what do we know about my car.
- give me my son's PESEL number?
- what does my wife like?
- what was the name of this search tool which we talked about?
- we talked about rap festival. tell me what we agreed.
- tell me what we know about my holidays plan""",
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

answer_internet_schema = {
    "name": "answerInternetQuestion",
    "description": """The user is looking for information about a certain thing, phenomenon or simply information and (importantly) does not refer directly to shared memory. Examples: 
- what is global warming?
- how to write code in python?
- what does it mean that something is ultra-right-wing?
- what will the weather be like tomorrow?
- who was John Paul 2
- what were the main events of the previous day?""",
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
        logger.warning(event)
        logger.warning(context)
        question = event['question']
        chat = ChatOpenAI(temperature=0, openai_api_key=get_secret()).bind(
            functions=[save_memory_schema, answer_memory_schema, answer_internet_schema])
        answer = chat.invoke([HumanMessage(question)])
        data = answer.additional_kwargs.get('function_call')
        data['arguments'] = json.loads(data['arguments'])
        logger.warning(data)
        return data
    except KeyError as e:
        logger.error(f"Missing key in JSON data: {str(e)}")
        # TODO error handling with step functions ??
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
