FROM python:3.13-alpine
WORKDIR /app
RUN pip install --no-cache-dir flask
COPY app.py .
EXPOSE 5050
CMD ["python", "app.py"]
