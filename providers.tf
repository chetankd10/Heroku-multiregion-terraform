terraform {
  required_version = ">= 1.5"

  required_providers {
    heroku = {
      source  = "heroku/heroku"
      version = "~> 5.0"
    }
  }
}

# Reads HEROKU_API_KEY (and optionally HEROKU_EMAIL) from the environment.
provider "heroku" {}
