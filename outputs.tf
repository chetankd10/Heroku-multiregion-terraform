output "app_url" {
  description = "Web URL for this instance"
  value       = heroku_app.instance.web_url
}

output "app_id" {
  description = "Heroku app ID, useful for `heroku` CLI commands"
  value       = heroku_app.instance.id
}
