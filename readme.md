# Homepage and DevOps Challenge Repository - Infrastructure

The infrastructure for my website in the form of terraform scripts for AWS.

The deplopyment assumes a role which is allowed to deploy S3, Cloudefront, IAM-Policies and other resources.

To execute, move into the aws folder and run 
```bash
terraform init 
terraform apply -var-file="default.tfvars"
```

The default.tfvars stores variables suited for my setup, which need to be adapted.