# California Region Variables - Lab 2 + TGW Hub Configuration

################################################################################
# PII REDACTION CONFIGURATION
# Variables for S3 Object Lambda + Amazon Comprehend PII Redaction
################################################################################

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "pii-redaction"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "force_destroy" {
  description = "Allow S3 buckets to be destroyed even when they contain objects"
  type        = bool
  default     = false
}

# EC2 Configuration for Lambda Layer Builder
variable "ec2_ami_id" {
  description = "AMI ID for EC2 instance (Amazon Linux 2023 recommended)"
  type        = string
  default     = "ami-05134c8ef96964280"  # Amazon Linux 2023 us-west-2
}

variable "pii_iam_instance_profile" {
  description = "IAM instance profile for PII EC2 (optional)"
  type        = string
  default     = ""
}

variable "pii_key_name" {
  description = "SSH key pair name for PII EC2"
  type        = string
  default     = "piiKP"                 # Ensure this matches the key pair in the correct Region
}

# S3 Access Point Names
variable "standard_access_point_name" {
  description = "Name for the standard S3 access point (supporting access point)"
  type        = string
  default     = "pii-standard-access-point"
}

variable "object_lambda_access_point_name" {
  description = "Name for the S3 Object Lambda access point"
  type        = string
  default     = "pii-object-lambda-access-point"
}

# Lambda Configuration
variable "pii_lambda_function_name" {
  description = "Name of the PII redaction Lambda function"
  type        = string
  default     = "pii-redaction-lambda"
}

variable "pii_lambda_role_name" {
  description = "Name of the IAM role for PII redaction Lambda"
  type        = string
  default     = "pii-redaction-lambda-role"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds (increase for large PDF files)"
  type        = number
  default     = 300  # 5 minutes for PDF processing
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB (increase for better PDF processing performance)"
  type        = number
  default     = 1024  # 1GB for PDF processing
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}

# PII Redaction Settings (based on AWS documentation)
variable "mask_character" {
  description = "Character to use for masking PII entities (e.g., '*')"
  type        = string
  default     = "*"
}

variable "mask_mode" {
  description = "Mask mode: MASK (use mask character) or REPLACE_WITH_PII_ENTITY_TYPE (show entity type)"
  type        = string
  default     = "MASK"

  validation {
    condition     = contains(["MASK", "REPLACE_WITH_PII_ENTITY_TYPE"], var.mask_mode)
    error_message = "mask_mode must be either 'MASK' or 'REPLACE_WITH_PII_ENTITY_TYPE'"
  }
}

variable "pii_entity_types" {
  description = "Comma-separated list of PII entity types to redact, or 'ALL' for all types. See: https://docs.aws.amazon.com/comprehend/latest/dg/how-pii.html"
  type        = string
  default     = "ALL"

  # Common PII entity types: NAME, ADDRESS, EMAIL, PHONE, SSN, CREDIT_DEBIT_NUMBER, 
  # CREDIT_DEBIT_CVV, CREDIT_DEBIT_EXPIRY, PIN, IP_ADDRESS, MAC_ADDRESS, 
  # DRIVER_ID, PASSPORT_NUMBER, BANK_ACCOUNT_NUMBER, BANK_ROUTING, etc.
}

################################################################################
# LEGACY VARIABLES (KEEP IF NEEDED FOR OTHER RESOURCES)
################################################################################

variable "domain_name" {
  description = "domain name: sebekgo.com"
  type        = string
  default     = "sebekgo.com"
}

variable "app_subdomain" {
  description = "App hostname prefix (e.g., app.sebekgo.com)."
  type        = string
  default     = "app"
}

variable "api_gateway_origin_subdomain" {
  description = "Dedicated API Gateway origin hostname prefix for CloudFront (e.g., origin.sebekgo.com)."
  type        = string
  default     = "origin"
}

variable "api_gateway_origin_cert_arn" {
  description = "Optional ACM cert ARN for the API Gateway origin hostname."
  type        = string
  default     = ""
}

variable "taaops" {
  description = "taaops project identifier"
  type        = string
  default     = "taaops"
}


# California VPC CONFIGURATION
variable "california_vpc_cidr" {
  description = "california VPC CIDR (use 10.x.x.x/xx as instructed)."
  type        = string
  default     = "10.233.0.0/16"
}


variable "california_subnet_public_cidrs" {
  description = "california public subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.233.1.0/24", "10.233.2.0/24", "10.233.3.0/24"]
}

variable "California_subnet_private_cidrs" {
  description = "california private subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.233.10.0/24", "10.233.11.0/24", "10.233.12.0/24"]
}

variable "California_azs" {
  description = "california Availability Zones list (match count with subnets)."
  type        = list(string)
  default     = ["us-west-1a", "us-west-1b", "us-west-1c"]
}

# SECURITY
variable "admin_ssh_cidr" {
  description = "CIDR allowed to SSH into EC2 instances."
  type        = string
  default     = "0.0.0.0/0"
}


variable "ec2_instance_type" {
  description = "EC2 instance size for the app."
  type        = string
  default     = "t3.micro"
}


# CERTIFICATE CONFIGURATION
variable "certificate_validation_method" {
  description = "ACM validation method for origin cert."
  type        = string
  default     = "DNS"
}

variable "aws_region_tls" {
  description = "Region for ACM certificate (us-east-1 for CloudFront)"
  type        = string
  default     = "us-east-1"
}

# SNS AND NOTIFICATIONS
variable "sns_email_endpoint" {
  description = "Email endpoint for SNS notifications"
  type        = string
  default     = "jastek.sweeney@gmail.com"
}

# ALARM CONFIGURATION
variable "alarm_reports_bucket_name" {
  description = "S3 bucket name for alarm reports"
  type        = string
  default     = "taaops-california-alarm-reports"
}

variable "rds_cluster_identifier" {
  description = "Aurora cluster identifier (override if a previous name is reserved)"
  type        = string
  default     = "taaops-aurora-cluster-02"
}

variable "rds_kms_key_arn" {
  description = "Override KMS key ARN for RDS encryption and master user secret."
  type        = string
  default     = ""
}

variable "rds_security_group_id" {
  description = "Override security group ID for the RDS cluster."
  type        = string
  default     = ""
}


# SECRETS ROTATION
variable "secrets_rotation_days" {
  description = "Number of days between Secrets Manager rotations"
  type        = number
  default     = 30
}

# AUTOMATION CONFIGURATION
variable "automation_parameters_json" {
  description = "JSON parameters for automation document"
  type        = string
  default     = "{\"Param1\":[\"value1\"],\"Param2\":[\"value2\"]}"
}




# INCIDENT REPORTING CONFIGURATION
variable "bedrock_model_id" {
  description = "Bedrock model ID for incident report generation"
  type        = string
  default     = "mistral.mistral-large-3-675b-instruct"
}

variable "incident_report_retention_days" {
  description = "Retention days for incident reports in S3"
  type        = number
  default     = 2555 # 7 years
}

variable "enable_bedrock" {
  description = "Enable Bedrock for AI-generated incident reports"
  type        = bool
  default     = true
}

variable "enable_redaction" {
  description = "Enable automatic redaction of incident reports"
  type        = bool
  default     = true
}


variable "enable_translation" {
  description = "Enable automatic translation of incident reports"
  type        = bool
  default     = true
}



# COMMON TAGS
variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Region      = "california"
    Purpose     = "Redaction"
    Environment = "production"
  }
}

# AUTOMATION AND MONITORING CONFIGURATION
variable "alarm_asg_name" {
  description = "Auto Scaling Group name for alarm monitoring"
  type        = string
  default     = "california-app-asg"
}

variable "automation_document_name" {
  description = "SSM automation document name for incident response"
  type        = string
  default     = "taaops-california-incident-report"
}






