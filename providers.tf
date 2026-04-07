# The default provider configuration; resources that begin with `aws_` will use
# it as the default, and it can be referenced as `aws`.

# California
# reference this as `aws.california`.
provider "aws" {
  region = "us-west-2"
}


#If adding other regions and changing default provider, uncomment the following code:

# California - reference this as `aws.california`.
# reference this as `aws.california`.
provider "aws" {
  alias  = "oregon"
  region = "us-west-2"
}


# Providers - terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.46.0" 
    }
  }

  backend "s3" {
    bucket       = "jastekops-zion"
    key          = "redacted/032526terraform.tfstate"
    region       = "us-west-1"  # Backend bucket location
    encrypt      = true
    # use_lockfile = true   #Enable for Highsec deployments
  }
} 
