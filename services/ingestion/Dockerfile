FROM python:3.11-slim

# System dependencies for GIS, GDAL, and SSL
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libgeos-dev \
    libproj-dev \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY . .

# Install package in editable mode
RUN pip install --no-cache-dir -e .

EXPOSE 8000

# Default command: run FastAPI monitoring server and scheduler
CMD ["python", "-m", "src.cli", "run-all"]
