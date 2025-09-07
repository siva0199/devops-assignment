# Build Stage
FROM python:3.9-slim as build

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Final Stage
FROM python:3.9-slim

WORKDIR /app
COPY --from=build /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY app.py .

CMD ["python", "app.py"]

