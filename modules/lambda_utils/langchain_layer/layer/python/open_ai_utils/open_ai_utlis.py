import logging

import openai
from langchain_openai import OpenAIEmbeddings

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_embeddings(text, ai_key):
    try:
        model_name = "text-embedding-3-small"
        embeddings = OpenAIEmbeddings(model=model_name, openai_api_key=ai_key)
        return embeddings.embed_query(text)
    except openai.error.InvalidRequestError as e:
        logger.error(f"Invalid request: {e}")
        raise e
    except openai.error.AuthenticationError as e:
        logger.error(f"Authentication error: {e}")
        raise e
    except openai.error.PermissionError as e:
        logger.error(f"Permission error: {e}")
        raise e
    except openai.error.RateLimitError as e:
        logger.error(f"Rate limit exceeded: {e}")
        raise e
    except openai.error.APIError as e:
        logger.error(f"API error: {e}")
        raise e
    except openai.error.Timeout as e:
        logger.error(f"Request timeout: {e}")
        raise e
    except Exception as e:
        logger.error(f"An unexpected error occurred: {e}")
        raise e
