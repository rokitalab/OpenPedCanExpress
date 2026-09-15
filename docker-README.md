# Running Preprocessing on EC2 with Docker

This guide explains how to run the multi-cohort preprocessing on an EC2 instance with sufficient memory.

## Prerequisites

- EC2 instance with **at least 64GB RAM** (e.g., `r7i.2xlarge`, `r6i.2xlarge`)
- Docker and Docker Compose installed
- Source data files in `data/source/`
- TAPESTRY preprocessing repo cloned alongside this repo

## Quick Start

### 1. Launch EC2 Instance

Choose a memory-optimized instance:
- **r7i.2xlarge** (8 vCPUs, 64GB RAM) - ~$0.50/hour
- **r6i.2xlarge** (8 vCPUs, 64GB RAM) - ~$0.50/hour
- **r7i.4xlarge** (16 vCPUs, 128GB RAM) - ~$1.00/hour (recommended for large datasets)

### 2. Install Docker

```bash
# Update system
sudo yum update -y

# Install Docker
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Log out and back in for group changes to take effect
```

### 3. Copy Data to EC2

From your local machine:

```bash
# Clone the repo
ssh ec2-user@<EC2-IP> "git clone https://github.com/rokitalab/OpenPedCanExpress.git"

# Copy source data
rsync -avz --progress data/source/ ec2-user@<EC2-IP>:~/OpenPedCanExpress/data/source/

# Copy TAPESTRY repo (for histologies)
rsync -avz --progress ../TAPESTRY-data-preprocessing/ ec2-user@<EC2-IP>:~/TAPESTRY-data-preprocessing/
```

### 4. Run Preprocessing

On EC2:

```bash
cd ~/OpenPedCanExpress

# Build the Docker image
docker-compose build

# Run preprocessing (will take 1-2 hours for multi-cohort)
docker-compose up

# Or run in detached mode and follow logs
docker-compose up -d
docker-compose logs -f
```

### 5. Download Results

From your local machine:

```bash
# Download the generated Parquet files
rsync -avz --progress ec2-user@<EC2-IP>:~/OpenPedCanExpress/data/partitions/*.parquet ./data/partitions/

# Verify the files
ls -lh data/partitions/*.parquet
```

### 6. Upload to S3

```bash
aws s3 cp data/partitions/genes_A-H.parquet s3://bti-openaccess-us-east-1-prd-rokita-lab/opc-express/v1/ --acl public-read
aws s3 cp data/partitions/genes_I-P.parquet s3://bti-openaccess-us-east-1-prd-rokita-lab/opc-express/v1/ --acl public-read
aws s3 cp data/partitions/genes_Q-Z.parquet s3://bti-openaccess-us-east-1-prd-rokita-lab/opc-express/v1/ --acl public-read
```

## Troubleshooting

### Out of Memory Errors

If you still hit memory limits, increase the allocation in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 128G  # Increase this
```

Or use a larger EC2 instance (e.g., `r7i.4xlarge` with 128GB RAM).

### Monitoring Progress

Watch the log file in real-time:

```bash
docker-compose logs -f preprocessing
```

### Check Memory Usage

```bash
# Inside the container
docker stats

# On the EC2 instance
free -h
htop
```

### Clean Up

```bash
# Stop and remove containers
docker-compose down

# Remove Docker images to free space
docker system prune -a
```

## Expected Runtime

- **PBTA only** (~2,300 samples): 30-45 minutes
- **Multi-cohort** (PBTA + TARGET + GMKF + DGD, ~3,800 samples): 1-2 hours

## Cost Estimate

Using `r7i.2xlarge` ($0.504/hour):
- **Multi-cohort preprocessing**: ~$1.00-$1.50
- Plus data transfer costs (~$0.09/GB out)

Remember to **terminate the EC2 instance** when done to avoid ongoing charges!
