import json
import hmac
import hashlib
import logging
import boto3
from custom_methods import get_secret

from models import SlackMessage

logger = logging.getLogger()
logger.setLevel(logging.INFO)
cached_slack_secret = None


def handler(event, context):
    slack_message = None
    request_body = json.loads(event['body'])
    try:
        slack_message = SlackMessage(request_body)
    except ValueError as e:
        logger.error(f"Error initializing SlackMessage: {e}")
    if verify(event) and slack_message is not None:
        if request_body['type'] == "url_verification":
            return {
                'statusCode': 200,
                'body': json.dumps({'challenge': request_body['challenge']})
            }
        elif slack_message.is_message_for_jarvan():
            # TODO here we will push messages to the SQS
            return {
                'statusCode': 200,
                'body': "Jarvan was called"
            }
        else:
            save_message(slack_message)
            return {
                'statusCode': 200,
                'body': "saved"
            }
    else:
        return {
            'statusCode': 500,
            'body': "Verification failed"
        }


def verify(event):
    global cached_slack_secret

    try:
        request_headers = event['headers']
        timestamp = request_headers['X-Slack-Request-Timestamp']
        slack_signature = request_headers['X-Slack-Signature']
    except KeyError as er:
        logger.error(f"Missing expected key: {er}")

    if not cached_slack_secret:
        cached_slack_secret = get_secret("SlackSigningSecret").encode('utf-8')

    base_string = f"v0:{timestamp}:{event['body']}"
    hmac_string = hmac.new(cached_slack_secret, base_string.encode('utf-8'), hashlib.sha256).hexdigest()
    computed_slack_signature = f'v0={hmac_string}'
    return computed_slack_signature == slack_signature


def save_message(slack_message):
    boto3.resource('dynamodb').Table('conversation').put_item(Item=slack_message.message)