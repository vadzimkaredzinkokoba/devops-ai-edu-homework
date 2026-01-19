# Development Environment Configuration
#
# This is a minimal development environment configuration.
# Copy from staging and adjust for development needs.

# See ../staging/ for complete configuration example.
# Dev environment typically uses:
# - Smaller task sizes
# - More aggressive cost optimization
# - Less strict HA requirements
# - Different networking (optional)

# To deploy dev environment:
# 1. Copy files from staging directory
# 2. Update backend.tf with dev-specific key
# 3. Adjust terraform.tfvars for dev settings
# 4. Run terraform init and apply
