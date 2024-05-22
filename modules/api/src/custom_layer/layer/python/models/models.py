from decimal import Decimal
from typing import Dict


class SlackMessage:
    """Encapsulates the message sent by the Slack API"""

    def __init__(self, body: Dict):
        self.body = body
        try:
            self.message_event = body["event"]
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

        self.authorizations = body.get("authorizations", [])

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

    def sanitized_text(self) -> str:
        """Removes bot id from direct messages"""
        bot_id = self.get_bot_id()
        text = self.message.get("text", "")
        if not bot_id:
            return text
        return text.replace(f"<@{bot_id}>", "").strip()

