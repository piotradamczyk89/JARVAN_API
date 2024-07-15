import logging
from langchain_openai import OpenAIEmbeddings

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_embeddings(text, ai_key):
    embeddings = OpenAIEmbeddings(model="text-embedding-3-small", openai_api_key=ai_key)
    value = embeddings.embed_query(text)
    print(value)
    return value
