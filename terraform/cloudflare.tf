locals {
  cloudflare_account_id = "974f94f87ea3d25fca82e9fb1f408b83"
}

resource "cloudflare_zone" "main" {
  account = {
    id = local.cloudflare_account_id
  }
  name = "pbonard.com"
}

# every subdomain (backend, holidayfriend, argocd-webhook, s3) straight to the home server, no cloudflare in front:
# its free plan sends korean users through los angeles, where requests and media crawled. a CNAME to turn's, so turn's
# ip updater keeps it on the home ip. dns only, so it's the home ip and not cloudflare's. the gateway serves each on
# 443 with its own listener (my-infra/k8s/bootstrap/gateway.yaml), reached through gateway-forwarder. turn's own A
# record wins over this one. the apex has no record, nothing is served there
resource "cloudflare_dns_record" "wildcard" {
  zone_id = cloudflare_zone.main.id
  name    = "*.pbonard.com"
  content = "turn.pbonard.com"
  type    = "CNAME"
  proxied = false
  # 1 is automatic
  ttl = 1
}

resource "cloudflare_dns_record" "turn" {
  zone_id = cloudflare_zone.main.id
  name    = "turn.pbonard.com"
  # placeholder, the turn service writes the home ip whenever it changes
  content = "127.0.0.1"
  type    = "A"
  proxied = false
  ttl     = 1

  lifecycle {
    ignore_changes = [content]
  }
}

output "cloudflare_nameservers" {
  value       = cloudflare_zone.main.name_servers
  description = "The nameservers of the zone, already set since the domain is registered at cloudflare"
}

output "cloudflare_zone_id" {
  value       = cloudflare_zone.main.id
  description = "The Cloudflare Zone ID for pbonard.com"
}

output "cloudflare_turn_record_id" {
  value       = cloudflare_dns_record.turn.id
  description = "The DNS Record ID for turn.pbonard.com"
}
