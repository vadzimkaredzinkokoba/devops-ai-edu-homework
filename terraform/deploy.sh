#!/bin/bash
#
# Helper script for deploying and managing ECS infrastructure
# Usage: ./deploy.sh [command]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-staging}"
REGION="${AWS_REGION:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/environments/$ENVIRONMENT"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Please install Terraform >= 1.9.0"
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install AWS CLI"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

bootstrap_backend() {
    log_info "Bootstrapping S3 backend..."
    
    cd "$SCRIPT_DIR/bootstrap"
    
    if [ ! -f "terraform.tfvars" ]; then
        log_warning "terraform.tfvars not found. Copying from example..."
        cp terraform.tfvars.example terraform.tfvars
        log_error "Please edit bootstrap/terraform.tfvars with your bucket name"
        exit 1
    fi
    
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan
    
    BUCKET_NAME=$(terraform output -raw state_bucket_name)
    log_success "S3 backend created: $BUCKET_NAME"
    
    cd "$SCRIPT_DIR"
}

init_environment() {
    log_info "Initializing $ENVIRONMENT environment..."
    
    if [ ! -d "$ENV_DIR" ]; then
        log_error "Environment directory not found: $ENV_DIR"
        exit 1
    fi
    
    cd "$ENV_DIR"
    
    if [ ! -f "terraform.tfvars" ]; then
        log_warning "terraform.tfvars not found. Using defaults..."
    fi
    
    terraform init
    log_success "Environment initialized"
}

plan_infrastructure() {
    log_info "Planning infrastructure for $ENVIRONMENT..."
    
    cd "$ENV_DIR"
    terraform plan -out=tfplan
    
    log_success "Plan created. Review and run 'terraform apply tfplan'"
}

deploy_infrastructure() {
    log_info "Deploying infrastructure for $ENVIRONMENT..."
    
    cd "$ENV_DIR"
    
    if [ ! -f "tfplan" ]; then
        log_info "No plan found. Creating plan..."
        terraform plan -out=tfplan
    fi
    
    terraform apply tfplan
    
    log_success "Infrastructure deployed!"
    
    # Display outputs
    echo ""
    log_info "Getting deployment information..."
    terraform output deployment_instructions
}

push_image() {
    log_info "Pushing Docker image to ECR..."
    
    cd "$ENV_DIR"
    
    ECR_REPO=$(terraform output -raw ecr_repository_url)
    
    if [ -z "$ECR_REPO" ]; then
        log_error "ECR repository not found. Deploy infrastructure first."
        exit 1
    fi
    
    log_info "ECR Repository: $ECR_REPO"
    
    # Login to ECR
    log_info "Logging in to ECR..."
    aws ecr get-login-password --region "$REGION" | \
        docker login --username AWS --password-stdin "$ECR_REPO"
    
    # Pull nginx image
    log_info "Pulling nginx:latest..."
    docker pull nginx:latest
    
    # Tag for ECR
    log_info "Tagging image..."
    docker tag nginx:latest "$ECR_REPO:latest"
    
    # Push to ECR
    log_info "Pushing to ECR..."
    docker push "$ECR_REPO:latest"
    
    log_success "Image pushed successfully!"
    log_info "Triggering ECS deployment..."
    
    # Force new deployment
    CLUSTER=$(terraform output -raw ecs_cluster_name)
    SERVICE=$(terraform output -raw ecs_service_name)
    
    aws ecs update-service \
        --cluster "$CLUSTER" \
        --service "$SERVICE" \
        --force-new-deployment \
        --region "$REGION" > /dev/null
    
    log_success "ECS deployment triggered"
    log_info "Wait ~2-3 minutes for tasks to start"
}

get_status() {
    log_info "Getting status for $ENVIRONMENT..."
    
    cd "$ENV_DIR"
    
    CLUSTER=$(terraform output -raw ecs_cluster_name)
    SERVICE=$(terraform output -raw ecs_service_name)
    
    aws ecs describe-services \
        --cluster "$CLUSTER" \
        --services "$SERVICE" \
        --region "$REGION" \
        --query 'services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount,Status:status}'
}

tail_logs() {
    log_info "Tailing logs for $ENVIRONMENT..."
    
    cd "$ENV_DIR"
    
    LOG_GROUP=$(terraform output -raw log_group_name)
    
    aws logs tail "$LOG_GROUP" --follow --region "$REGION"
}

destroy_infrastructure() {
    log_warning "This will destroy all infrastructure for $ENVIRONMENT"
    read -p "Are you sure? (yes/no): " -r
    
    if [ "$REPLY" != "yes" ]; then
        log_info "Cancelled"
        exit 0
    fi
    
    cd "$ENV_DIR"
    
    log_info "Destroying infrastructure..."
    terraform destroy -auto-approve
    
    log_success "Infrastructure destroyed"
}

show_help() {
    cat << EOF
ECS Infrastructure Deployment Helper

Usage: $0 [environment] [command]

Environment: dev, staging, prod (default: staging)

Commands:
    bootstrap       Bootstrap S3 backend (one-time setup)
    init           Initialize Terraform for environment
    plan           Create Terraform plan
    deploy         Deploy infrastructure
    push-image     Build and push Docker image to ECR
    status         Show ECS service status
    logs           Tail CloudWatch logs
    destroy        Destroy all infrastructure
    help           Show this help message

Examples:
    $0 staging bootstrap   # Create S3 backend
    $0 staging deploy      # Deploy staging environment
    $0 staging push-image  # Push nginx image
    $0 staging status      # Check service status
    $0 staging destroy     # Destroy infrastructure
    
    $0 dev deploy          # Deploy dev environment

EOF
}

# Main script
main() {
    COMMAND="${2:-help}"
    
    case "$COMMAND" in
        bootstrap)
            check_prerequisites
            bootstrap_backend
            ;;
        init)
            check_prerequisites
            init_environment
            ;;
        plan)
            check_prerequisites
            plan_infrastructure
            ;;
        deploy)
            check_prerequisites
            init_environment
            deploy_infrastructure
            ;;
        push-image)
            check_prerequisites
            push_image
            ;;
        status)
            check_prerequisites
            get_status
            ;;
        logs)
            check_prerequisites
            tail_logs
            ;;
        destroy)
            check_prerequisites
            destroy_infrastructure
            ;;
        help|*)
            show_help
            ;;
    esac
}

main "$@"
