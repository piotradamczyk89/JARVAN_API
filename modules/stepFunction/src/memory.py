import logging
import time
import uuid
from custom_methods import slack_bot_response
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    slack_bot_response(event['arguments'])


def create_memory(memory):
    _id = str(uuid.uuid4())
    memory.update({"id": _id, "timestamp": int(time.time())})
    boto3.resource('dynamodb').Table('conversation').put_item(Item=memory)
