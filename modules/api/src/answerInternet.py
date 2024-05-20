import json
import boto3
import logging
from serpapi import GoogleSearch
from custom_methods import get_secret
logger = logging.getLogger()
logger.setLevel(logging.INFO)

system_message = """You have to answer a human question as short as possible. 
RULES $$$
- use only information from links in context to to answer questions

CONTEXT $$$
{context}
"""

human_message = "{question}"

dynamo = boto3.resource('dynamodb')
table = dynamo.Table('conversation')


def handler(event, context):
    try:
        params = {
            "q": event['arguments']['question'],
            "location": "Poland",
            "hl": "pl",
            "gl": "PL",
            "google_domain": "google.com",
            "api_key": get_secret("SerpAPI")
        }
        search = GoogleSearch(params)
        result = search.get_dict()
        result = result.get('organic_results')[0].get('link')
        return {"reply": result}
    except KeyError as e:
        logger.error(f"Missing key in JSON data: {str(e)}")
        return {
            "statusCode": 400,  # Bad Request
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Missing data: {str(e)}"})
        }

    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON format: {str(e)}")
        return {
            "statusCode": 400,  # Bad Request
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Invalid JSON format"})
        }
    except Exception as e:
        logger.error(f"Internal Server Error: {str(e)}")
        return {
            "statusCode": 500,  # Internal Server Error
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Internal server error"})
        }
