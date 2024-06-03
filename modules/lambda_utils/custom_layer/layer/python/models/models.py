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
                "timestamp": Decimal(self.message_event["event_ts"])
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
