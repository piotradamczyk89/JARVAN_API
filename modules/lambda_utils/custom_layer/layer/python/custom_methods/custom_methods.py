import json
import os

import requests
import logging
from models import ParameterStoreCache

logger = logging.getLogger()
logger.setLevel(logging.INFO)
WORKSPACE = os.getenv('WORKSPACE', '')
parameter_store_cache = ParameterStoreCache()


def slack_bot_response(message):
    slack_token = parameter_store_cache.get_parameter(WORKSPACE + "-slack_bot_oAuth_token")
    if not slack_token:
        logger.error("Error: Slack token could not be retrieved.")
        return None
    data = {
        "channel": WORKSPACE + "_life",
        "text": message
    }
    json_data = json.dumps(data, ensure_ascii=False)
    headers = {"Content-Type": "application/json; charset=utf-8", "Authorization": f'Bearer {slack_token}'}
    try:
        response = requests.post("https://slack.com/api/chat.postMessage", data=json_data.encode('utf-8'),
                                 headers=headers)
        response.raise_for_status()
        if not response.json().get("ok"):
            logger.error(f"Error from Slack API: {response.json().get('error')}")
            return None
        return response
    except requests.exceptions.RequestException as e:
        logger.error(f"HTTP Request failed: {e}")
        return None
