# the cloudflare tunnel and its dns, as they were in terraform/cloudflare.tf until 2026-11-17 (see
# cloudflared-tunnel.yaml). to bring back: copy into terraform/, add hashicorp/random (~> 3.0) back to
# provider.tf's required_providers, and replace cloudflare.tf's dns-only wildcard with the records below

locals {
  # cloudflared routes every hostname of the zone to the envoy gateway, the gateway picks the service by hostname
  envoy_gateway = "http://static-envoy-ingress.envoy-gateway-system.svc.cluster.local:80"
}

resource "cloudflare_dns_record" "apex" {
  zone_id = cloudflare_zone.main.id
  name    = "pbonard.com"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.kind_cluster.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  # 1 is automatic
  ttl = 1
}

# every subdomain (*.pbonard.com) goes through the tunnel too
resource "cloudflare_dns_record" "wildcard" {
  zone_id = cloudflare_zone.main.id
  name    = "*.pbonard.com"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.kind_cluster.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

resource "random_id" "tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "kind_cluster" {
  account_id = local.cloudflare_account_id
  name       = "local-kind-cluster"
  # the ingress rules are kept at cloudflare (the config resource below), not in a local config file
  config_src    = "cloudflare"
  tunnel_secret = random_id.tunnel_secret.b64_std

  lifecycle {
    # the api never returns the secret, an imported tunnel would otherwise be replaced to set it again
    ignore_changes = [tunnel_secret]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "kind_cluster_config" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.kind_cluster.id

  config = {
    ingress = [
      {
        hostname = "pbonard.com"
        service  = local.envoy_gateway
      },
      {
        hostname = "*.pbonard.com"
        service  = local.envoy_gateway
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "kind_cluster" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.kind_cluster.id
}

output "tunnel_token" {
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.kind_cluster.token
  sensitive   = true
  description = "The token required for the cloudflared pod."
}
