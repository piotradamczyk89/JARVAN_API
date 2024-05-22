import json

import boto3
from botocore.exceptions import ClientError
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_secret(secret_name):
    region_name = os.getenv('my_aws_region', 'eu-central-1')
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'DecryptionFailureException':
            logger.error("Secrets Manager can't decrypt the protected secret text using the provided KMS key.")
        elif e.response['Error']['Code'] == 'InternalServiceErrorException':
            logger.error("An error occurred on the server side.")
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            logger.error("You provided an invalid value for a parameter.")
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            logger.error("You provided a parameter value that is not valid for the current state of the resource.")
        elif e.response['Error']['Code'] == 'ResourceNotFoundException':
            logger.error("We can't find the resource that you asked for.")
        else:
            logger.error("An unknown error occurred:", e)
        raise e

    secret = json.loads(get_secret_value_response['SecretString'])['key']
    return secret

