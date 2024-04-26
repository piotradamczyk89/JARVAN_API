import json
import boto3
from botocore.exceptions import ClientError
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI


def handler(event, context):
    event = json.loads(event["body"])
    question = event['question']
    system_message = SystemMessage("answer user question as short as possible")
    human_message = HumanMessage(question)
    chat = ChatOpenAI(openai_api_key=get_secret())
    answer = chat.invoke(
        ChatPromptTemplate.from_messages([system_message, human_message]).format_prompt())

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"reply": answer.content})
    }


def get_secret():
    secret_name = "openAIKey"
    region_name = "eu-central-1"

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
        print(e)
        raise e

    secret = json.loads(get_secret_value_response['SecretString'])['key']
    return secret
