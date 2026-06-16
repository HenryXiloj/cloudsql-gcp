# Demos GCP Repository
====================

This repository contains demo projects showcasing how to use Google Cloud services such as Cloud SQL, Pub/Sub, BigQuery, Dataflow, Dataproc, Cloud Composer, Cloud Run, Cloud Functions, Workload Identity Federation, VPC networks, and more, along with tools like Terraform, Spring Boot, Flask, Maven, and Docker for infrastructure and application deployment.

## Projects Overview

### Private Service Connect (PSC)
1. **Terraform GCP Infrastructure Setup**
    - This demo project uses Terraform to provision Google Cloud resources such as VPC networks, subnets, firewalls, and Cloud SQL instances.
    - **Key Features**:
        - Private Service Connect (PSC) for Cloud SQL
        - VPC and NAT Gateway configuration
        - IAM roles and permissions management
    - More details in the project README: [PSC Terraform README](https://github.com/HenryXiloj/demos-gcp/tree/main/cloudsql/private-service-connect-PSC/terraform)

2. **Spring Boot Cloud SQL with Private Service Connect**
    - A Spring Boot 3 application built with Java 17, demonstrating the use of Cloud SQL PostgreSQL with Private Service Connect for secure database access.
    - **Key Features**:
        - PostgreSQL integration via PSC
        - Dockerized application for easy deployment
        - REST API with basic CRUD operations
    - More details in the project README: [Spring Boot PSC README](https://github.com/HenryXiloj/demos-gcp/tree/main/cloudsql/private-service-connect-PSC/cloud-run-spring-boot3)

3. **Flask App with Cloud SQL Connector**
    - This project shows how to use the Cloud SQL Python Connector with a Flask application to connect to a PostgreSQL instance using Private Service Connect.
    - **Key Features**:
        - Python Flask app with GCP integration
        - Secure Cloud SQL connection using the Cloud SQL Python Connector
        - Dockerized application for local or cloud-based deployment
    - More details in the project README: [Flask PSC README](https://github.com/HenryXiloj/demos-gcp/tree/main/cloudsql/private-service-connect-PSC/cloud-run-python3.12)

### Private Service Access (Private IP & Public IP)
4. **Private and Public IP Cloud SQL Demo**
    - A Terraform configuration to deploy Cloud SQL instances with both public and private IPs, along with a Spring Boot application demonstrating how to connect to both instances.
    - **Key Features**:
        - Cloud SQL with Private Service Connect and public IP
        - Secure IAM roles and firewall rules
        - Application configurations for both types of IPs
    - More details in the project README: [Private and Public IP Cloud SQL README](https://github.com/HenryXiloj/demos-gcp/tree/main/cloudsql/private-service-access-PrivateIP-PublicIP/terraform)

5. **Spring Boot Demo with Cloud SQL (Public and Private IP)**
    - A Spring Boot project that demonstrates connecting to Cloud SQL instances using both public and private IPs, with a focus on containerization using Docker.
    - **Key Features**:
        - Private Service Connect (PSC) for enhanced security
        - Public IP-based database access for flexibility
        - Docker for easy deployment and scalability
    - More details in the project README: [Spring Boot Public & Private IP README](https://github.com/HenryXiloj/demos-gcp/tree/main/cloudsql/private-service-access-PrivateIP-PublicIP/cloud-run-spring-boot3)

### AWS and Google Cloud Federation
6. **AWS to Google Cloud Workload Identity Federation**
    - A Terraform project that lets AWS workloads access Google Cloud Storage through Workload Identity Federation without service account keys.
    - **Key Features**:
        - Workload Identity Pool for AWS and EKS federation
        - EKS Kubernetes OIDC and EC2/AWS IAM authentication paths
        - Service account impersonation with scoped Cloud Storage permissions
    - More details in the project README: [GCP AWS Federation README](gcp-aws-federation/README.md)

### Pub/Sub and Event-Driven Architecture
7. **Pub/Sub with Terraform and Spring Boot 3**
    - A Terraform and Spring Boot 3 demo for provisioning Pub/Sub topics and subscriptions and processing messages from a Java 21 application.
    - **Key Features**:
        - Pub/Sub topic and subscription provisioning with Terraform
        - Spring Boot 3 publisher and subscriber integration
        - `spring-cloud-gcp-starter-pubsub` messaging support
    - More details in the project README: [Pub/Sub README](pubsub/README.md)

### Data and Analytics
8. **Dataflow Demos**
    - Data pipeline demos for moving and transforming data with Google Cloud Dataflow, BigQuery, Cloud SQL, Pub/Sub, and Cloud Storage.
    - **Key Features**:
        - Cloud SQL to BigQuery pipeline examples
        - File ingestion from Cloud Storage to BigQuery and Pub/Sub
        - Terraform-based infrastructure examples
    - More details in the project folder: [Dataflow Demos](dataflow)

9. **Dataproc Cluster on GCE**
    - A Dataproc demo for provisioning and working with a cluster on Google Compute Engine.
    - **Key Features**:
        - Dataproc cluster provisioning
        - GCE-based compute resources
        - Terraform deployment workflow
    - More details in the project README: [Dataproc README](dataproc-cluster-gce/README.md)

10. **PostgreSQL CDC to BigQuery Streaming**
    - A streaming demo for sending PostgreSQL change data capture events to BigQuery.
    - **Key Features**:
        - PostgreSQL CDC source data
        - BigQuery streaming destination
        - Cloud-native data integration workflow
    - More details in the project README: [PostgreSQL CDC to BigQuery README](pg-cdc-to-bq-streaming/README.md)

### Orchestration, Serverless, and Cloud SQL
11. **Cloud Composer v3 Demos**
    - Cloud Composer v3 demos that cover Composer networking and Cloud SQL integration patterns.
    - **Key Features**:
        - Composer v3 with Cloud SQL Private Service Access
        - Static and dynamic Cloud VPN routing examples
        - Terraform-based environment setup
    - More details in the project folder: [Composer v3 Demos](composer-v3)

12. **Cloud SQL on Cloud Run Demo**
    - A Cloud Run demo that connects an application to Cloud SQL.
    - **Key Features**:
        - Cloud Run deployment
        - Cloud SQL application connectivity
        - Containerized application workflow
    - More details in the project README: [Cloud SQL Cloud Run README](demo-cloudsql-cloudrun/README.md)

13. **Google Cloud Functions Demo**
    - A Google Cloud Functions demo project.
    - **Key Features**:
        - Serverless function deployment
        - Google Cloud SDK workflow
        - Lightweight event or HTTP function pattern
    - More details in the project README: [Cloud Functions README](demo-gcp-cf/README.md)

## Common Setup Instructions

### Prerequisites
- Terraform installed and configured for GCP projects.
- Google Cloud SDK installed and authenticated.
- [Java 17](https://docs.azul.com/core/release/17-ga/release-notes), [Java 21](https://docs.azul.com/core/release/21-ga/release-notes/tpl), [Maven](https://maven.apache.org/install.html), and Docker for application development and containerization.
- AWS account, IAM role details, or EKS OIDC issuer details for the AWS to Google Cloud Workload Identity Federation demo.

### Running Terraform Projects
1. Clone the repository.
2. Navigate to the desired project directory.
```bash
   terraform init
   terraform fmt
   terraform validate
   terraform plan
   terraform apply -auto-approve
   terraform destroy -auto-approve
```


### Running Spring Boot or Flask Applications
```bash
    mvn clean package
    docker build -t <app-name> .
    docker run -p 8080:8080 <app-name>
```
```bash
    pip install -r requirements.txt
    docker build -t <app-name> .
    docker run -p 8080:8080 <app-name>
```

Key GCP Services Used
---------------------

*   **VPC Networks**: Custom VPC networks for secure and isolated cloud environments.
    
*   **Cloud SQL (PostgreSQL)**: Managed relational databases with Private Service Connect for secure access.
    
*   **IAM Roles and Permissions**: Fine-grained access control for resources and service accounts.
    
*   **Private Service Connect (PSC)**: Private access to GCP services, enhancing security and compliance.

*   **Workload Identity Federation (WIF)**: Keyless federation from AWS IAM roles or EKS Kubernetes service accounts into Google Cloud.

*   **Cloud Storage**: Object storage used by federation and data pipeline examples.

*   **Pub/Sub**: Messaging service for publisher, subscriber, and event-driven architecture demos.

*   **BigQuery**: Analytics destination for batch, streaming, and CDC examples.

*   **Dataflow**: Managed stream and batch processing for data movement and transformations.

*   **Dataproc**: Managed Spark and Hadoop clusters for data processing workloads.

*   **Cloud Composer**: Managed Apache Airflow environments for orchestration.

*   **Cloud Run and Cloud Functions**: Serverless compute options for containerized apps and functions.
    

This README provides a high-level overview of the demo projects and the infrastructure setup involved in deploying applications with Google Cloud services. For more detailed information, please refer to the individual project READMEs.
