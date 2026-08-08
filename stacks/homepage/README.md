# Homepage (GetHomepage)

This stack runs the GetHomepage dashboard using the official image.

Quick start

From this folder:

```bash
# start in detached mode
docker compose -f compose.yml up -d

# follow logs
docker logs -f homepage
```

Notes

- The container reads configuration from the `config/` directory (mounted into `/app/config`). Edit `bookmarks.yaml`, `services.yaml`, `widgets.yaml`, and `settings.yaml` to customise.
- The compose file sets the `HOMEPAGE_ALLOWED_HOSTS` environment variable. Make sure it includes the host and port you use to access the app (for example `homepage.example.com,localhost:9595`).
- For production, place a reverse proxy (Traefik/Nginx) in front of the service and enable TLS/Let's Encrypt. You can add Traefik labels to the service or create a separate router.
- Optional: mount `/var/run/docker.sock` (already done) and populate `config/docker.yaml` if you want Docker-related widgets.

Example Traefik label snippet (if you run Traefik in the same Docker network):

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.homepage.rule=Host(`homepage.yourdomain.tld`)"
  - "traefik.http.routers.homepage.entrypoints=websecure"
  - "traefik.http.routers.homepage.tls.certresolver=letsencrypt"
  - "traefik.http.services.homepage.loadbalancer.server.port=3000"
```

Troubleshooting

- If you see "Host validation failed" in `config/logs/homepage.log`, ensure `HOMEPAGE_ALLOWED_HOSTS` includes the host:port you used and that the value is quoted in `compose.yml`.

