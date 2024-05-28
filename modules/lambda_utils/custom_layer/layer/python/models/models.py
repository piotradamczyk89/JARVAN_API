import json
from decimal import Decimal
from typing import Dict


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
