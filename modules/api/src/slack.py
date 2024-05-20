import json
import hmac
import hashlib

from custom_methods import get_secret


def handler(event, context):
    request_body = json.loads(event['body'])
    print(event['body'])
    request_headers = event['headers']
    timestamp = request_headers['X-Slack-Request-Timestamp']
    slack_signature = request_headers['X-Slack-Signature']
    if request_body['type'] == "url_verification":
        return {
            'statusCode': 200,
            'body': json.dumps({'challenge': request_body['challenge']})
        }
    else:
        return {
            'statusCode': 200,
            'body': json.dumps({'verfiy': verify(timestamp, event['body'], slack_signature)})
        }


def verify(timestamp, request_body, slack_signature):
    signing_secret = get_secret("SlackSigningSecret").encode('utf-8')
    base_string = f"v0:{timestamp}:{request_body}"
    hmac_string = hmac.new(signing_secret, base_string.encode('utf-8'), hashlib.sha256).hexdigest()
    computed_slack_signature = f'v0={hmac_string}'
    return computed_slack_signature == slack_signature

