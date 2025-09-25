# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# TERRAGRUNT CONFIGURATION
# =============================================================================
# This file defines Terragrunt-specific configuration for managing Terraform
# deployments with enhanced automation, error handling, and variable management

# -----------------------------------------------------------------------------
# TERRAFORM EXECUTION CONFIGURATION
# -----------------------------------------------------------------------------
# Configures how Terragrunt executes Terraform commands with custom arguments
# and variable file handling for streamlined deployment workflows

terraform {
  
  # ---------------------------------------------------------------------------
  # VARIABLE FILE MANAGEMENT
  # ---------------------------------------------------------------------------
  # Automatically loads custom variable files for all Terraform commands
  # that require variable inputs (plan, apply, destroy, refresh, etc.)
  
  extra_arguments "custom_vars" {
    # Apply to all Terraform commands that need variable files
    # This includes: plan, apply, destroy, refresh, import, etc.
    commands = get_terraform_commands_that_need_vars()

    # Optional variable files to load if they exist
    # Terragrunt will not fail if these files are missing
    optional_var_files = [
      "./variables.tfvars",
    ]
  }

  # ---------------------------------------------------------------------------
  # APPLY COMMAND AUTOMATION
  # ---------------------------------------------------------------------------
  # Configures automatic approval and refresh behavior for apply operations
  # to enable unattended deployments in CI/CD pipelines
  
  extra_arguments "auto_apply" {  # Renamed from "custom_vars" to avoid conflicts
    # Apply only to the apply command
    commands = [
      "apply",
    ]

    # Command line arguments for automated apply operations
    arguments = [
      "-auto-approve",
      "--refresh=true"
    ]
  }

  # ---------------------------------------------------------------------------
  # DESTROY COMMAND AUTOMATION  
  # ---------------------------------------------------------------------------
  # Configures automatic approval for destroy operations
  # WARNING: Use with extreme caution in production environments
  
  extra_arguments "auto_destroy" {  # Renamed from "custom_vars" to avoid conflicts
    # Apply only to the destroy command
    commands = [
      "destroy"
    ]

    # Command line arguments for automated destroy operations
    arguments = [
      "-auto-approve",
      "--refresh=true"
    ]
  }
}
# =============================================================================
# ERROR HANDLING AND RETRY CONFIGURATION
# =============================================================================
# Defines patterns for transient errors that should trigger automatic retries
# rather than failing the entire deployment operation

# -----------------------------------------------------------------------------
# RETRYABLE ERROR PATTERNS
# -----------------------------------------------------------------------------
# Regular expressions matching error messages that indicate transient failures
# These errors will trigger automatic retries with exponential backoff

errors {
  retry "retry" {
    max_attempts       = 10
    sleep_interval_sec = 10
    retryable_errors   = [  
      # ---------------------------------------------------------------------------
      # NETWORK TIMEOUT ERRORS
      # ---------------------------------------------------------------------------
      # Network timeouts can occur due to temporary connectivity issues,
      # slow API responses, or network congestion - retry these operations
      # 
      # Pattern explanation:
      # (?s) - enables single-line mode (dot matches newlines)
      # .* - matches any characters (including newlines)
      # This pattern catches any error message containing "i/o timeout"
      "(?s).*i/o timeout",
      
      # ---------------------------------------------------------------------------
      # ADDITIONAL COMMON RETRY PATTERNS
      # ---------------------------------------------------------------------------
      # Uncomment and customize these patterns as needed for your environment
      
      # API rate limiting errors
      # "(?s).*rate limit.*exceeded.*",
      # "(?s).*too many requests.*",
      
      # Temporary service unavailability
      # "(?s).*service unavailable.*",
      # "(?s).*temporary failure.*",
      
      # Connection and SSL errors
      # "(?s).*connection reset.*",
      # "(?s).*ssl handshake timeout.*",
      # "(?s).*dial tcp.*connection refused.*",
      
      # Cloud provider specific errors
      # "(?s).*RequestLimitExceeded.*",        # AWS
      # "(?s).*ProvisioningConflict.*",        # Azure
      # "(?s).*quotaExceeded.*",               # GCP
      # "(?s).*TooManyRequests.*",             # Generic HTTP 429
    ]
  }
}


# =============================================================================
# CONFIGURATION BEST PRACTICES AND SECURITY NOTES
# =============================================================================

# -----------------------------------------------------------------------------
# PRODUCTION DEPLOYMENT CONSIDERATIONS
# -----------------------------------------------------------------------------
# 
# 1. AUTO-APPROVE SAFETY:
#    - The auto-approve flags eliminate interactive confirmations
#    - Ensure proper CI/CD gates and approvals are in place
#    - Consider using manual approval for production destroy operations
#
# 2. VARIABLE FILE SECURITY:
#    - Store sensitive variables in encrypted files or secret management systems
#    - Use .gitignore to prevent accidental commit of sensitive tfvars files
#    - Consider using Terragrunt's built-in secret management features
#
# 3. STATE MANAGEMENT:
#    - Ensure remote state backend is configured for team collaboration
#    - Use state locking to prevent concurrent modifications
#    - Implement regular state backups
#
# 4. ERROR HANDLING:
#    - Monitor retry patterns to identify systematic issues
#    - Implement alerting for repeated failures
#    - Consider circuit breaker patterns for external service calls

# -----------------------------------------------------------------------------
# ENVIRONMENT-SPECIFIC OVERRIDES
# -----------------------------------------------------------------------------
# 
# For different environments (dev/staging/prod), consider:
# 
# Development:
# - Keep auto-approve for faster iteration
# - More aggressive retry patterns
# - Shorter timeouts
#
# Production:
# - Remove auto-approve for critical operations  
# - Conservative retry patterns
# - Extended timeouts for large deployments
# - Additional validation steps