import json
import logging
import os

import boto3
from custom_methods import get_secret
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
cached_AIKey = None


def handler(event, context):
    global cached_AIKey
    if cached_AIKey is None:
        cached_AIKey = get_secret("AIKey")
    try:
        logger.info(event)
        for record in event['Records']:
            body = json.loads(record['body'])
            question = body['text']
            logger.info(question)
            chat = ChatOpenAI(temperature=0, openai_api_key=cached_AIKey).bind(
                functions=[save_memory_schema, answer_memory_schema, answer_internet_schema])
            answer = chat.invoke([HumanMessage(question)])
            data = answer.additional_kwargs.get('function_call')
            data['arguments'] = json.loads(data['arguments'])
            data.update({"metadata": body})
            logger.info(data)
            step_function_arn = os.getenv('STEP_FUNCTION_ARN', '')
            client = boto3.client('stepfunctions')
            try:
                response = client.start_execution(stateMachineArn=step_function_arn, input=json.dumps(data))
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'Step Function started successfully',
                        'executionArn': response['executionArn']
                    })
                }
            except Exception as e:
                return {
                    'statusCode': 500,
                    'body': json.dumps({
                        'message': 'Error starting Step Function',
                        'error': str(e)
                    })
                }
    except KeyError as e:
        logger.error(f"Missing key in JSON data: {str(e)}")
        raise
    except Exception as er:
        logger.error(f"Exception: {str(er)}")
        raise
