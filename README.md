# Secure and Scalable Nginx Web Service with AWS and Terraform

This repository contains Terraform configurations to create a secure and scalable Nginx web service in AWS with multi-Availability Zone (multi-AZ) architecture. It also sets up an RDS server accessible to the web servers.

## Task Requirements

- Create a Nginx web service that utilizes multi-AZ in AWS.
- Allow access to the web service only from specific Client's public IPs.
- Set up an RDS server that’s accessible to the web servers.
- Ensure all configurations are as secure as possible.
- Implement auto-scaling for web servers based on CPU load thresholds.
- Use Terraform to create all infrastructure components.

## Getting Started

To deploy this infrastructure, follow these steps:

1. Change values in the inputs.auto.tfvars file accordingly:
   ```sh
   example...
   acm_arn = "arn:aws:acm:us-east-1:137694460137:certificate/529b2200-af97-4ddc-b7fa-5216af89b48a"

2. Clone this repository:

   ```sh
   git clone https://github.com/AndrewsHerrera/softserve.git
   cd softserve

   ```sh
   terraform init

   ```sh
   terraform apply

Security Considerations
Security groups and network ACLs are configured to allow access only from specified public IPs.
IAM roles and least privilege principles are used for resource access.
RDS data is encrypted at rest and in transit.
VPC flow logs and CloudTrail are enabled for monitoring and auditing.
Scaling
Web servers are set to automatically scale up when CPU load hits 65% or higher and scale down when it's 40% or lower.

Cleanup
To remove the deployed resources and avoid ongoing costs, run:

   ```sh
   terraform destroy


