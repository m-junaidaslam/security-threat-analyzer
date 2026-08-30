terraform {
  backend "s3" {
    bucket       = "configure-with-backend-config"
    key          = "infrastructure/terraform.tfstate"
    use_lockfile = true
  }
}