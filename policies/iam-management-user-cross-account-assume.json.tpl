{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAssumeRoleToReadOnlyConsoleRoles",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [
        "arn:aws:iam::{DEV_ACCOUNT}:role/{PROJECT_SHORT_NAME}-dev",
        "arn:aws:iam::{STAGING_ACCOUNT}:role/{PROJECT_SHORT_NAME}-staging",
        "arn:aws:iam::{PROD_ACCOUNT}:role/{PROJECT_SHORT_NAME}-prod"
      ]
    }
  ]
}
