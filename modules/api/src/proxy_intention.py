import json
import logging
import os

import boto3
from botocore.exceptions import ClientError
from langchain_core.messages import HumanMessage
from langchain_openai import ChatOpenAI

from custom_methods import slack_bot_response
from models import SecretManagerCache
from models import MissingSecretException

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
secret_manager_cache = SecretManagerCache()
error_message = "coś poszło nie tak"


def handler(event, context):
    try:
        ai_key = secret_manager_cache.get_secret("AIKey")
        logger.info("event is " + str(event))
        for record in event.get('Records', []):
            body = json.loads(record.get('body', '{}'))
            question = body.get('text')
            if not question:
                logger.error("No question found in the message body.")
                continue
            logger.info("question is " + question)
            data = define_intention(key=ai_key, question=question)
            del body['text']
            data.update({"metadata": body})
            send_message_to_sqs(data)
    except MissingSecretException as e:
        logger.error(f"Missing Secret Exception: {str(e)}")
        slack_bot_response(error_message)
    except KeyError as e:
        logger.error(f"Missing key in JSON data: {str(e)}")
        slack_bot_response(error_message)
    except Exception as er:
        logger.error(f"Exception: {str(er)}")
        slack_bot_response(error_message)


def make_open_ai_call(key, question, model="gpt-3.5-turbo"):
    chat = ChatOpenAI(temperature=0, openai_api_key=key, model=model).bind(
        functions=[save_memory_schema, answer_memory_schema])
    answer = chat.invoke([HumanMessage(question)])
    return answer.additional_kwargs.get('function_call')


def define_intention(key, question):
    data = make_open_ai_call(key=key, question=question)
    if data is None:
        data = make_open_ai_call(key=key, question=question, model="gpt-4o")
    if data is None:
        data = {"name": "dontKnowHowToRespondToThat"}
    return data


def send_message_to_sqs(data):
    logger.info("data moved to step function is " + str(data))
    step_function_arn = os.getenv('STEP_FUNCTION_ARN', '')
    client = boto3.client('stepfunctions')
    try:
        response = client.start_execution(stateMachineArn=step_function_arn, input=json.dumps(data))
        logger.info(json.dumps({
            'message': 'Step Function started successfully',
            'executionArn': response['executionArn']
        }))
    except ClientError as e:
        logger.error(f"Error starting Step Function: {str(e)}")
        slack_bot_response(error_message)
