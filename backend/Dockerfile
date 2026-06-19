FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN python -c "from database import engine; from models import Base; Base.metadata.create_all(bind=engine)"

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8000

CMD ["/bin/sh", "/start.sh"]
