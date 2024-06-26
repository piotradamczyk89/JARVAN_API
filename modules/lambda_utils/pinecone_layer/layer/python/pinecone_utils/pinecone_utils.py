import time

from pinecone import Pinecone, ServerlessSpec


def get_vector_base_index(pine_cone_key):
    index_name = "brain"
    pc = Pinecone(api_key=pine_cone_key)
    if index_name not in pc.list_indexes().names():
        pc.create_index(
            name=index_name,
            dimension=1536,
            metric="cosine",
            spec=ServerlessSpec(
                cloud="aws",
                region="us-east-1"
            )
        )
        while not pc.describe_index(index_name).status['ready']:
            time.sleep(1)

    return pc.Index(index_name)
