import redis.asyncio as redis
import os

redis_client = None

async def get_redis():
    global redis_client
    if redis_client is None:
        redis_client = redis.from_url(os.getenv("REDIS_URL"))
    return redis_client