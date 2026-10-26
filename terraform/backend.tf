
terraform {
  backend "s3" {
    bucket       = "gwphillips-portfolio-tfstate-165030185216"
    key          = "portfolio/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
