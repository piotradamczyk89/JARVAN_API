import json
import hmac
import hashlib
import logging
import os
import boto3
from models import SlackMessage, ParameterStoreCache
from models import DecimalEncoder

logger = logging.getLogger()
logger.setLevel(logging.INFO)
parameter_store_cache = ParameterStoreCache()
WORKSPACE = os.getenv('WORKSPACE', '')


def handler(event, context):
    request_body = json.loads(event['body'])
    if request_body["type"] == "url_verification":
        return {
            'statusCode': 200,
            'body': json.dumps({'challenge': request_body['challenge']})
        }
    try:
        slack_message = SlackMessage(request_body)
    except KeyError as e:
        logger.error(f"Error initializing SlackMessage: {e}")
        return {
            'statusCode': 500,
            'body': f"Error initializing SlackMessage: {e}"
        }
    if verify(event) and slack_message is not None:
        satus_code = 200
        body = "saved"
        save_message(slack_message)
        if slack_message.is_message_for_jarvan():
            client = boto3.client("sqs")
            response = client.send_message(QueueUrl=os.getenv('SQS_URL', ''),
                                           MessageBody=json.dumps(slack_message.sanitized_message(),
                                                                  cls=DecimalEncoder),
                                           MessageGroupId='slack')
            satus_code = response["ResponseMetadata"]["HTTPStatusCode"]
            body = json.dumps(response["ResponseMetadata"])
        return {
            'statusCode': satus_code,
            'body': body
        }
    else:
        logger.error("Slack message corrupted or verification failed")
        return {
            'statusCode': 500,
            'body': "Verification failed"
        }


def verify(event):
    try:
        request_headers = event['headers']
        timestamp = request_headers['X-Slack-Request-Timestamp']
        slack_signature = request_headers['X-Slack-Signature']
    except KeyError as er:
        logger.error(f"Missing expected key when verifying slack message: {er}")
        return False
    secret = parameter_store_cache.get_parameter(WORKSPACE + "-slack_signing_secret").encode('utf-8')

    if secret is None:
        logger.error("Error: parameter from parameter was not retrieved.")
        return False
    base_string = f"v0:{timestamp}:{event['body']}"
    hmac_string = hmac.new(secret, base_string.encode('utf-8'), hashlib.sha256).hexdigest()
    computed_slack_signature = f'v0={hmac_string}'
    return computed_slack_signature == slack_signature


def save_message(slack_message):
    boto3.resource('dynamodb').Table(WORKSPACE+'-conversation').put_item(Item=slack_message.message)
