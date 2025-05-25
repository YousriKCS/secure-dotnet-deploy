#!/bin/bash
source ./cloudflare.env


# Nieuwe IP voor je A-records
NEW_IP=$(gcloud compute forwarding-rules describe dotnet-https-forwarding-rule \
    --global \
    --format="get(IPAddress)")

NEW_IPV6=$(gcloud compute forwarding-rules describe dotnet-https-ipv6 \
    --global \
    --format="get(IPAddress)")

# Controleer of NEW_IP een geldig IP is
echo "New IP: $NEW_IP"
echo "New IPv6: $NEW_IPV6"

# Update root domain A record (pentacoders.com)
curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$ROOT_RECORD_ID" \
    -H "Authorization: Bearer 1fM68ptmnLW1b_q_CUZqBYArT2Hw2oTqp2zQ7p-d" \
    -H "Content-Type: application/json" \
    --data '{
        "type": "A",
        "name": "pentacoders.com",
        "content": "'"$NEW_IP"'",
        "ttl": 1,
        "proxied": true
    }'

# Update www subdomain A record (www.pentacoders.com)
curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$WWW_RECORD_ID" \
    -H "Authorization: Bearer 1fM68ptmnLW1b_q_CUZqBYArT2Hw2oTqp2zQ7p-d" \
    -H "Content-Type: application/json" \
    --data '{
        "type": "A",
        "name": "www.pentacoders.com",
        "content": "'"$NEW_IP"'",
        "ttl": 1,
        "proxied": true
    }'

# Update AAAA-records
curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$ROOT_AAAA_RECORD_ID" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "AAAA",
    "name": "pentacoders.com",
    "content": "'"$NEW_IPV6"'",
    "ttl": 1,
    "proxied": true
  }'

curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$WWW_AAAA_RECORD_ID" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "AAAA",
    "name": "www.pentacoders.com",
    "content": "'"$NEW_IPV6"'",
    "ttl": 1,
    "proxied": true
  }'




echo "✅ DNS records updated successfully!"