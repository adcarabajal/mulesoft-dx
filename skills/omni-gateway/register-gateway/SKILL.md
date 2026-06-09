---
name: register-gateway
description: |
  Register a self-managed Omni Gateway instance with Anypoint Platform and
  generate the registration token saved to the conf.d directory. Use when the
  user wants to connect a self-managed gateway to Anypoint's control plane,
  obtain the registration YAML file after installing Omni Gateway on Linux,
  Docker, or Kubernetes, or re-register a gateway after a token expires or
  a new environment is needed.
---

# Register Gateway

## Overview

Registering a gateway connects your self-managed Omni Gateway instance to Anypoint Platform's control plane. The `flexctl registration create` command contacts Anypoint, creates a gateway record in Runtime Manager, and generates a registration YAML file that the gateway reads at startup to authenticate and receive policies from Anypoint.

## Prerequisites

- Omni Gateway already installed and running (see `install-omni-gateway` for setup)
- Anypoint organization ID (UUID format)
- A registration token from Anypoint Runtime Manager → Add Gateway → Self-managed → Copy token
- For Docker: Docker installed and `mulesoft/flex-gateway` image pulled
- For Linux: `flexctl` command available in `$PATH` (included with Flex Gateway installation)

## Step 1 — Gather registration parameters

Before running the registration command, collect the following from the user:

1. **Gateway name** (`<gateway-name>`): A unique, human-readable identifier (alphanumeric and hyphens only, e.g., `prod-gateway-1`). This name appears in Anypoint Runtime Manager and should reflect the deployment environment.

2. **Anypoint organization ID** (`<orgID>`): The UUID-format organization ID visible in Anypoint Platform → Admin Settings → Organization. Format: `550e8400-e29b-41d4-a716-446655440000`.

3. **Registration token** (`<token>`): Obtained from Anypoint Runtime Manager → Add Gateway → Self-managed tab → Copy token button. This token is scoped to a specific organization and environment and expires after 24 hours.

4. **Deployment platform**: Linux, Docker, or Kubernetes.

5. **Output directory** (Linux only): The conf.d directory where the registration YAML will be saved. Default is `/usr/local/share/mulesoft/flex-gateway/conf.d`, but it may differ if Flex Gateway was installed to a custom location.

## Step 2 — Run flexctl registration create

Execute the `flexctl registration create` command on the target platform. The command contacts Anypoint, registers the gateway, and writes the registration YAML file to the specified directory.

### Linux

On the Linux host where Flex Gateway is installed, run:

```bash
sudo flexctl registration create <gateway-name> \
  --token=<token> \
  --organization=<orgID> \
  --connected=true \
  --anypoint-url=https://anypoint.mulesoft.com \
  --output-directory=/usr/local/share/mulesoft/flex-gateway/conf.d
```

Replace placeholders:
- `<gateway-name>`: e.g., `prod-gateway-1`
- `<token>`: Your 24-hour registration token
- `<orgID>`: Your Anypoint organization UUID
- `--output-directory`: Path to conf.d (adjust if Flex Gateway is installed elsewhere)

The command should complete in 10–15 seconds. If successful, you'll see a message confirming the registration YAML was written.

### Docker

When running Flex Gateway in Docker, generate the registration YAML on your host machine and then mount it into the container. Run this one-shot container command in your working directory:

```bash
docker run --entrypoint flexctl -u $UID \
  -v "$(pwd)":/registration mulesoft/flex-gateway \
  registration create \
  --organization=<orgID> \
  --token=<token> \
  --output-directory=/registration \
  --connected=true \
  --anypoint-url=https://anypoint.mulesoft.com \
  <gateway-name>
```

This command:
- Runs `flexctl` inside the container (via `--entrypoint`)
- Mounts the current working directory into the container as `/registration`
- Writes the registration YAML into that directory
- Uses `-u $UID` to ensure the file is owned by your user

After the command completes, the registration YAML file will be in your current directory. Move it to the persistent volume directory where you'll mount it when starting the Flex Gateway container.

### Kubernetes

For Kubernetes deployments, first generate the registration YAML on your workstation using the Docker method above, then supply it to the Helm chart:

```bash
# Step 1: Generate registration YAML (run the Docker command above)
docker run --entrypoint flexctl -u $UID \
  -v "$(pwd)":/registration mulesoft/flex-gateway \
  registration create \
  --organization=<orgID> \
  --token=<token> \
  --output-directory=/registration \
  --connected=true \
  --anypoint-url=https://anypoint.mulesoft.com \
  <gateway-name>

# Step 2: Install or upgrade the Helm chart with the registration file
helm install flex-gateway mulesoft/flex-gateway \
  --namespace gateway \
  --create-namespace \
  --set-file registration.content=<registration-yaml-file> \
  --values values.yaml
```

Or for an existing deployment:

```bash
helm upgrade flex-gateway mulesoft/flex-gateway \
  --namespace gateway \
  --set-file registration.content=<registration-yaml-file>
```

The Helm chart automatically mounts the registration file into the correct conf.d directory inside the pod.

## Step 3 — Verify the registration artifact

Check that the registration YAML file was created successfully and contains the expected content.

### Linux

```bash
ls -la /usr/local/share/mulesoft/flex-gateway/conf.d/
```

Look for a file with a name like `registration.yaml` (exact filename depends on the gateway name). View its contents:

```bash
cat /usr/local/share/mulesoft/flex-gateway/conf.d/registration.yaml
```

The file should start with `kind: Configuration` and include `spec.platformConnection` fields with:
- `agentId`: The gateway's unique identifier in Anypoint
- `arm`: The Anypoint Runtime Manager endpoint URL
- `clientId` and `clientSecret`: Credentials for platform authentication

### Docker

After running the Docker command, the registration YAML should be in your current directory:

```bash
ls -la registration.yaml
cat registration.yaml
```

Verify it contains `kind: Configuration` and `spec.platformConnection` fields. Then move it to the volume directory you'll use when starting the Flex Gateway container:

```bash
mv registration.yaml /path/to/persistent/volume/conf.d/
```

### Kubernetes

After the Helm install or upgrade completes, verify the pod received the registration file:

```bash
kubectl exec -it -n gateway deployment/flex-gateway -- \
  cat /usr/local/share/mulesoft/flex-gateway/conf.d/registration.yaml
```

## Step 4 — Restart or start the gateway

Once the registration YAML is in place, start or restart the gateway so it reads the registration file and establishes a connection to Anypoint.

### Linux

If the Flex Gateway service is not yet running:

```bash
sudo systemctl start flex-gateway
```

If it's already running, restart it to load the registration:

```bash
sudo systemctl restart flex-gateway
```

Check the service status:

```bash
sudo systemctl status flex-gateway
```

### Docker

Start the Flex Gateway container with the conf.d volume mounted:

```bash
docker run -d \
  --name flex-gateway \
  -v /path/to/conf.d:/usr/local/share/mulesoft/flex-gateway/conf.d \
  mulesoft/flex-gateway
```

Or if using Docker Compose, ensure your `docker-compose.yaml` mounts the conf.d directory:

```yaml
volumes:
  - /path/to/conf.d:/usr/local/share/mulesoft/flex-gateway/conf.d
```

Then:

```bash
docker-compose up -d
```

### Kubernetes

After the Helm install completes, the pod will start automatically. If the chart is already deployed, trigger a rollout restart to pick up the new registration:

```bash
kubectl rollout restart deployment/flex-gateway -n gateway
```

Watch the pod come online:

```bash
kubectl get pods -n gateway -w
```

## Step 5 — Confirm in Anypoint Runtime Manager

Verify that the gateway appears online and is communicating with Anypoint. You have two options:

### Option 1: Anypoint Platform UI

1. Navigate to **Anypoint Platform** → **Runtime Manager** → **Flex Gateways**
2. Look for your gateway by name (e.g., `prod-gateway-1`)
3. Confirm that the status shows **STARTED** (green indicator)
4. The gateway should be listed with its organization and any associated environments

### Option 2: Flex Gateway Manager API

Query the Flex Gateway Manager API to verify the gateway and its registration status:

**Get gateway details:**
```
GET https://anypoint.mulesoft.com/flexgateway/api/v1/organizations/{orgID}/environments/{envID}/gateways/{gatewayID}
Authorization: Bearer <access-token>
```

Expect a 200 response with `status: STARTED`.

**Get registration-specific status:**
```
GET https://anypoint.mulesoft.com/flexgateway/api/v1/organizations/{orgID}/environments/{envID}/gateways/{gatewayID}/registration
Authorization: Bearer <access-token>
```

This returns registration details including the `agentId`, connection timestamp, and any recent registration errors.

**Alternative:** Use the Flex Gateway Manager API skill (`urn:api:flex-gateway-manager`) from within a Claude agent workflow to query these endpoints programmatically.

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| `authentication failed` or `401 Unauthorized` | Token has expired or is incorrect | Generate a fresh registration token from Anypoint Runtime Manager → Add Gateway → Self-managed, then re-run the command |
| `environment not found` or `404` | Organization ID is wrong or token is scoped to a different organization | Verify the org ID in Anypoint Admin Settings and regenerate the token in the correct organization |
| `permission denied` or `conf.d not writable` | The output directory has restrictive permissions | Run `sudo chown -R $USER /usr/local/share/mulesoft/flex-gateway/conf.d` (Linux) or adjust volume permissions (Docker/Kubernetes) |
| `409 Conflict` — gateway already registered | A gateway with the same name already exists in Anypoint | Use a different `<gateway-name>`, or delete the old gateway record from Runtime Manager first |
| Status stays `DISCONNECTED` after restart | Registration file is not in conf.d, or the gateway is using the wrong conf.d path | Verify the file exists: `ls -la /usr/local/share/mulesoft/flex-gateway/conf.d/`. For Docker/Kubernetes, ensure the volume mount path is correct |
| `flexctl: command not found` (Linux) | `flexctl` is not in `$PATH` | Ensure Flex Gateway was installed correctly; reinstall if needed, or add the installation directory to `$PATH` |

## Related Jobs

- `install-omni-gateway` — Install and configure Omni Gateway before registering
- `validate-gateway-config` — Validate the registration YAML and other conf.d files for correctness
