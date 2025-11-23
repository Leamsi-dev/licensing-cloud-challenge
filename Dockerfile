FROM python:3.11.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*

COPY docker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/
COPY docker/init-keys.sh /init-keys.sh
RUN chmod +x /init-keys.sh

EXPOSE 8000

CMD ["/init-keys.sh"]