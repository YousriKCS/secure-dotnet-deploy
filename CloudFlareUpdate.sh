#!/bin/bash
source ./cloudflare.env

# Nieuwe IPv4 en IPv6 IP-adressen van de Load Balancer
NEW_IP=$(gcloud compute forwarding-rules describe dotnet-https-forwarding-rule \
    --global \
    --format="get(IPAddress)")

NEW_IPV6=$(gcloud compute forwarding-rules describe dotnet-https-ipv6 \
    --global \
    --format="get(IPAddress)")

echo "New IPv4: $NEW_IP"
echo "New IPv6: $NEW_IPV6"



# Update A-record (IPv4) voor root domein
curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$ROOT_RECORD_ID" \
    -H "Authorization: Bearer 1fM68ptmnLW1b_q_CUZqBYArT2Hw2oTqp2zQ7p-d" \
    -H "Content-Type: application/json" \
    --data '{
        "type": "A",
        "name": "pentacoders.com",
        "content": "'"$NEW_IP"'",
        "ttl": 1,
        "proxied": false
    }'

# Update A-record (IPv4) voor www subdomein
curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$WWW_RECORD_ID" \
    -H "Authorization: Bearer 1fM68ptmnLW1b_q_CUZqBYArT2Hw2oTqp2zQ7p-d" \
    -H "Content-Type: application/json" \
    --data '{
        "type": "A",
        "name": "www.pentacoders.com",
        "content": "'"$NEW_IP"'",
        "ttl": 1,
        "proxied": false
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
    "proxied": false
  }'

curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$WWW_AAAA_RECORD_ID" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "AAAA",
    "name": "www.pentacoders.com",
    "content": "'"$NEW_IPV6"'",
    "ttl": 1,
    "proxied": false
  }'


# Purge cache
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
    -H "Authorization: Bearer $API_KEY_PURGE" \
    -H "Content-Type: application/json" \
    --data '{
        "purge_everything": true
    }'

echo "✅ DNS records (IPv4 & IPv6) updated successfully!"
