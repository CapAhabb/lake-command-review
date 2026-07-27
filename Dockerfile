FROM python:3.13-slim

WORKDIR /app
COPY public ./public

EXPOSE 4173
CMD ["python", "-m", "http.server", "4173", "-d", "public"]

