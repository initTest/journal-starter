FROM python:3.11-slim

WORKDIR /app

# system deps for psycopg2 / builds
RUN apt-get update && \
    apt-get install -y build-essential libpq-dev && \
    rm -rf /var/lib/apt/lists/*

# copy source and requirements
COPY . /app
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

EXPOSE 8000
ENV PYTHONUNBUFFERED=1

# do NOT bake secrets (.env) into the image; pass at runtime
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]