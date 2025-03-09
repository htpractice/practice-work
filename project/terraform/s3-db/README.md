# Use of s3-db.tf
- This file will be used to create a s3 bucket and dynamodb table.
- Dynamodb table is created to store the terraform lock.
- This lock will assure the single user tfstate execution.