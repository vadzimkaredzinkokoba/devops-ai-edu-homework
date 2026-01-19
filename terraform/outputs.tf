output "instructions" {
  description = "Instructions for deploying infrastructure"
  value       = <<-EOT
    
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                     ECS Nginx Infrastructure Deployment                     ║
    ╚════════════════════════════════════════════════════════════════════════════╝
    
    This root module is for reference. Deploy infrastructure using environment-specific configurations:
    
    DEPLOYMENT STEPS:
    
    1. Bootstrap S3 State Bucket (one-time setup):
       cd bootstrap/
       terraform init
       terraform apply
       cd ..
    
    2. Deploy Staging Environment:
       cd environments/staging/
       terraform init
       terraform apply
    
    3. Push Docker Image to ECR:
       # Get ECR login
       aws ecr get-login-password --region us-east-1 | \
         docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
       
       # Build and push nginx image
       docker pull nginx:latest
       docker tag nginx:latest <ECR_REPOSITORY_URL>:latest
       docker push <ECR_REPOSITORY_URL>:latest
    
    4. Access Application:
       Application URL: http://<ALB_DNS_NAME>
    
    For detailed instructions, see terraform/README.md
    
  EOT
}
