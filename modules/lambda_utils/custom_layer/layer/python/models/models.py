import json
import logging
import os
from decimal import Decimal
from typing import Dict

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class SlackMessage:
    """Encapsulates the message sent by the Slack API"""

    def __init__(self, body: Dict):
        self.body = body
        self.authorizations = body.get("authorizations", [])
        self.type = body['type']
        try:
            self.message_event = body["event"]
            self.text = self.message_event["text"]
        except KeyError as er:
            raise ValueError(f"Missing expected key: {er}")
        try:
            self.message = {
                "text": self.message_event["text"],
                "userID": self.message_event["user"],
                "timestamp": str(self.message_event["event_ts"])
            }
        except KeyError as er:
            raise ValueError(f"Missing expected key in message event: {er}")

    def is_bot_reply(self) -> bool:
        return "bot_id" in self.message_event

    def get_bot_id(self) -> str:
        if not self.authorizations:
            return ""

        try:
            return self.authorizations[0]["user_id"]
        except (IndexError, KeyError) as er:
            raise ValueError(f"Error accessing bot ID: {er}")

    def is_message_for_jarvan(self) -> bool:
        bot_id = self.get_bot_id()
        return bot_id and f"<@{bot_id}>" in self.message.get("text", "")

    def sanitized_message(self) -> dict:
        """Removes bot id from direct messages"""
        bot_id = self.get_bot_id()
        if not bot_id:
            return self.message
        self.message.update({"text": self.message.get("text").replace(f"<@{bot_id}>", "").strip()})
        return self.message


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


class ParameterStoreCache:
    _cache = {}

    def __init__(self):
        region_name = os.getenv('MY_AWS_REGION', 'eu-central-1')
        self.ssm = boto3.client('ssm', region_name=region_name)

    def get_parameter(self, name, with_decryption=False):
        logger.info("i am in get parameter")
        logger.info(self._cache)
        if name in self._cache:
            return self._cache[name]

        try:
            response = self.ssm.get_parameter(
                Name=name,
                WithDecryption=with_decryption
            )
            parameter_value = response['Parameter']['Value']
            self._cache[name] = parameter_value
            return parameter_value
        except ClientError as e:
            print(f"An error occurred: {e}")
            return None


class SecretManagerCache:
    _cache = {}

    def __init__(self):
        region_name = os.getenv('MY_AWS_REGION', 'eu-central-1')
        session = boto3.session.Session()
        self.client = session.client(
            service_name='secretsmanager',
            region_name=region_name
        )

    def get_secret(self, name):
        if name in self._cache:
            return self._cache[name]

        try:
            get_secret_value_response = self.client.get_secret_value(
                SecretId=name
            )
            secret = json.loads(get_secret_value_response['SecretString'])['key']
            self._cache[name] = secret
            return secret
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_messages = {
                'DecryptionFailureException': "Secrets Manager can't decrypt the protected secret text using the provided KMS key.",
                'InternalServiceErrorException': "An error occurred on the server side.",
                'InvalidParameterException': "You provided an invalid value for a parameter.",
                'InvalidRequestException': "You provided a parameter value that is not valid for the current state of the resource.",
                'ResourceNotFoundException': "We can't find the resource that you asked for."
            }

            error_message = error_messages.get(error_code, f"An unknown error occurred: {e}")
            logger.error(error_message)
            raise e
