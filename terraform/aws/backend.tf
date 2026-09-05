terraform {
  backend "s3" {
    key          = "auspost-devops-demo/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
