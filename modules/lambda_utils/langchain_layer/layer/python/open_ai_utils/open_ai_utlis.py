import logging

import openai

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_embeddings(text):
    try:
        response = openai.Embedding.create(
            input=text,
            model="text-embedding-ada-002"  # or whichever model you are using
        )
        return response['data'][0]['embedding']
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
