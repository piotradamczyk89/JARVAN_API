import logging
from openai import OpenAIError
from langchain_openai import OpenAIEmbeddings
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_embeddings(text, ai_key):
    try:
        embeddings = OpenAIEmbeddings(model="text-embedding-3-small", openai_api_key=ai_key)
        value = embeddings.embed_query(text)
        print(value)
        return value
    except OpenAIError as e:
        logger.error(f"Open AI Error: {e}")
        raise e
    except Exception as e:
        logger.error(f"An unexpected error occurred: {e}")
        raise e
