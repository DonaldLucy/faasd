# faasd + Junctiond Integration (Dev Notes)

## What this fork is

The repository is a fork of `openfaas/faasd`.  
The goal of this fork is to add an **optional alternative runtime** (Junctiond) for OpenFaaS functions, alongside the default `containerd` runtime.

Right now:

- The **faasd core services** (gateway, nats, queue-worker, prometheus, etc.) still run on containerd.
- The **function lifecycle path** (`/system/functions`, deploy/update/delete/scale) is where we will integrate Junctiond via gRPC.
- We already have a working faasd environment and a custom `faasd-provider` binary built from this fork.

You can develop and test Junctiond integration *without touching* the core faasd system services.

---

## 1. Bring up faasd on a fresh machine

Tested on Ubuntu 24.04.

### Install base dependencies

```bash
sudo apt-get update
sudo apt-get install -y git containerd curl

# Kernel settings for faasd networking
sudo modprobe br_netfilter
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
````

### Clone this fork

```bash
cd ~
git clone https://github.com/DonaldLucy/faasd.git
cd faasd
```

### Run the upstream installer

This uses the upstream faasd release binary to set up systemd units, CNI plugins, etc.

```bash
sudo ./hack/install.sh
```

Check that services are running:

```bash
sudo systemctl status faasd
sudo systemctl status faasd-provider
```

Both should show `active (running)`.

---

## 2. Build and install our custom faasd binary

We want to run the **provider** and **faasd** using the code from this fork.

From the repo root:

```bash
cd ~/faasd

# Build faasd and faasd-arm64 binaries
make
# Output: bin/faasd, bin/faasd-arm64
```

Stop existing services and replace the binary:

```bash
sudo systemctl stop faasd faasd-provider

sudo cp bin/faasd /usr/local/bin/faasd
sudo chmod +x /usr/local/bin/faasd
```

Start the main faasd service again:

```bash
sudo systemctl start faasd
sudo systemctl status faasd
```

At this point, both `faasd` and `faasd-provider` **will use our forked binary** once the provider is restarted.

---

## 3. Enable the Junctiond feature flag for the provider

We use an environment variable on the provider’s systemd unit:

```bash
sudo systemctl edit faasd-provider
```

In the editor, add:

```ini
[Service]
Environment=FAASD_USE_JUNCTION=1
```

Save, then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart faasd-provider
sudo systemctl status faasd-provider
```

Now the provider runs with our forked binary and has `FAASD_USE_JUNCTION=1` in its environment.
The Go code can read this flag to switch on Junctiond-related logic.

---

## 4. Talking directly to the provider (port 8081)

The provider exposes the OpenFaaS provider API on port **8081**.
This bypasses the gateway and is the easiest way to test our integration.

Get the default admin password:

```bash
PASSWORD=$(sudo cat /var/lib/faasd/secrets/basic-auth-password)
```

Keep a log window open for the provider:

```bash
sudo journalctl -u faasd-provider -f
```

Check provider health:

```bash
curl -s -u admin:$PASSWORD http://127.0.0.1:8081/system/info | jq
curl -s -u admin:$PASSWORD http://127.0.0.1:8081/system/functions | jq
```

You should see:

* `/system/info`: JSON with `"provider": "faasd-ce"` and `"orchestration": "containerd"`.
* `/system/functions`: initially `[]`.


The log window shows deploy / delete / scale logs and any `[Junction] ...` messages we add.

---

## 5. Deploying a test function via the provider

From another terminal:

```bash
PASSWORD=$(sudo cat /var/lib/faasd/secrets/basic-auth-password)

curl -i -u admin:$PASSWORD \
  -X POST http://127.0.0.1:8081/system/functions \
  -H "Content-Type: application/json" \
  -d '{
    "service": "nodeinfo2",
    "image": "ghcr.io/openfaas/nodeinfo:latest",
    "envProcess": "node index.js"
  }'
```

Expected behavior:

* First deploy → `HTTP/1.1 200 OK`.
* Provider logs show:

  * function count, namespace count
  * image pull via containerd
  * container/task creation and CNI IP (e.g. `nodeinfo2 has IP: 10.62.0.10`).

List functions:

```bash
curl -s -u admin:$PASSWORD http://127.0.0.1:8081/system/functions | jq
```

You should see a function:

```json
[
  {
    "name": "nodeinfo2",
    "image": "ghcr.io/openfaas/nodeinfo:latest",
    "namespace": "openfaas-fn",
    "replicas": 1,
    ...
  }
]
```

---

## 6. Where Junctiond fits in

The main integration points in this fork are:

* `pkg/provider/handlers/deploy.go`
* `pkg/provider/handlers/delete.go`
* `pkg/provider/handlers/scale.go`
* `pkg/provider/handlers/update.go`
* `pkg/provider/handlers/invoke_resolver.go` (resolving function name → IP/port)

Right now, these handlers still use `containerd` and CNI to manage the function processes.

The Junctiond Go client lives under:

```text
pkg/junctiond/junctiond/proto/client.go
```

It exposes something like:

```go
type Client struct { ... }

func New(sock string) (*Client, error)
func (c *Client) Spawn(ctx context.Context, f *FunctionData) error
func (c *Client) Remove(ctx context.Context, name string) error
func (c *Client) List(ctx context.Context) ([]*FunctionStatus, error)
```

The plan is:

* When `FAASD_USE_JUNCTION == "1"`, we can fork the behavior in these handlers:

  * Option A: **hybrid mode** — keep using containerd, but also call `junctiond.Spawn()` / `Remove()` in parallel for experiments.
  * Option B: **Junction‑only mode** — skip containerd and let Junctiond manage the actual function processes (you’ll need to provide IP/port to the gateway).

When your Junctiond daemon is ready and listening on a Unix socket (e.g. `/run/junctiond.sock`), you can:

1. Implement or adjust the Go client in `pkg/junctiond/junctiond/proto/client.go`.
2. Wire it into the handlers (especially `deploy.go`) behind the `FAASD_USE_JUNCTION` feature flag.
3. Use the curl examples above to trigger deploys and see Junctiond being invoked.

---

## 7. Known caveat: 502 from the gateway (port 8080)

The OpenFaaS gateway on port `8080` currently returns `502` for some endpoints like `/system/functions`. This is a separate networking issue between the gateway container and the provider.

For Junctiond development and testing, **you can ignore the gateway and talk directly to the provider on `8081`**.
Once the Junction integration is stable at the provider layer, we can come back and fix the gateway–provider path and `faas-cli login`.

````



# What we *should* add (conceptually, ask chat when Junctiond is deployed)

Inside `pkg/provider/handlers/deploy.go`, there is currently something like:

```go
func deploy(ctx context.Context, req types.FunctionDeployment, client *containerd.Client, cni gocni.CNI, secretMountPath string, alwaysPull bool) error {
    // 1. Snapshotter selection
    // 2. prepull image via service.PrepareImage(...)
    // 3. prepare env/mounts
    // 4. build containerd container
    // 5. createTask(...) → containerd task + CNI IP
}
```

Pseudo-Codes and Placeholder are there to integrate Junction






