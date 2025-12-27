# Prometheus Metrics Monitoring

OSX Cleaner provides a built-in Prometheus metrics endpoint for remote monitoring of disk usage and cleanup statistics.

## Quick Start

### Starting the Metrics Server

```bash
# Start with default settings (port 9090)
osxcleaner metrics start

# Start with custom port
osxcleaner metrics start --port 8080

# Run in foreground (useful for debugging)
osxcleaner metrics start --foreground
```

### Viewing Metrics

```bash
# Display current metrics in Prometheus format
osxcleaner metrics show

# Check server status
osxcleaner metrics status

# Via curl
curl http://localhost:9090/metrics
```

### Stopping the Server

```bash
osxcleaner metrics stop
```

## Available Metrics

### Disk Usage Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `osxcleaner_disk_total_bytes` | Gauge | Total disk space in bytes |
| `osxcleaner_disk_available_bytes` | Gauge | Available disk space in bytes |
| `osxcleaner_disk_used_bytes` | Gauge | Used disk space in bytes |
| `osxcleaner_disk_usage_percent` | Gauge | Disk usage percentage (0-100) |

### Cleanup Statistics Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `osxcleaner_cleanup_operations_total` | Counter | Total number of cleanup operations performed |
| `osxcleaner_bytes_cleaned_total` | Counter | Total bytes cleaned by cleanup operations |
| `osxcleaner_files_removed_total` | Counter | Total files removed by cleanup operations |
| `osxcleaner_directories_removed_total` | Counter | Total directories removed by cleanup operations |
| `osxcleaner_cleanup_errors_total` | Counter | Total errors during cleanup operations |
| `osxcleaner_last_cleanup_timestamp` | Gauge | Unix timestamp of last cleanup operation |

### System Info Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `osxcleaner_info` | Gauge | OSX Cleaner version information |

## Prometheus Configuration

Add the following to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'osxcleaner'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 30s
```

A complete example configuration is available at [`prometheus.yml`](prometheus.yml).

## Grafana Dashboard

A pre-built Grafana dashboard is available at [`grafana-dashboard.json`](grafana-dashboard.json).

### Importing the Dashboard

1. Open Grafana and navigate to Dashboards > Import
2. Upload the `grafana-dashboard.json` file or paste its contents
3. Select your Prometheus data source
4. Click Import

### Dashboard Panels

The dashboard includes:

- **Disk Usage Gauge**: Current disk usage percentage with warning/critical thresholds
- **Available/Used/Total Space**: Current disk space statistics
- **Disk Usage Over Time**: Historical disk usage graph
- **Cleanup Statistics**: Total operations, bytes cleaned, files removed
- **Bytes Cleaned Over Time**: Historical cleanup volume

## Health Check Endpoint

The metrics server also provides a health check endpoint:

```bash
curl http://localhost:9090/health
```

Response:
```json
{"status":"ok"}
```

## Alerting Examples

### Prometheus Alert Rules

```yaml
groups:
  - name: osxcleaner
    rules:
      - alert: DiskUsageHigh
        expr: osxcleaner_disk_usage_percent > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage detected"
          description: "Disk usage is {{ $value }}%"

      - alert: DiskUsageCritical
        expr: osxcleaner_disk_usage_percent > 95
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Critical disk usage detected"
          description: "Disk usage is {{ $value }}%"

      - alert: CleanupErrors
        expr: increase(osxcleaner_cleanup_errors_total[1h]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High number of cleanup errors"
          description: "{{ $value }} cleanup errors in the last hour"
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/metrics` | GET | Prometheus metrics in exposition format |
| `/health` | GET | Health check endpoint |
| `/` | GET | Same as `/metrics` |

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `--port` | 9090 | Port to listen on |
| `--host` | 127.0.0.1 | Host to bind to |
| `--foreground` | false | Run in foreground mode |
| `--labels` | true | Include labels in metrics output |

## Security Considerations

By default, the metrics server only binds to `localhost` (127.0.0.1). To expose metrics externally:

```bash
osxcleaner metrics start --host 0.0.0.0
```

**Warning**: Exposing metrics externally may reveal system information. Consider using a reverse proxy with authentication if exposing to untrusted networks.

## Troubleshooting

### Server Won't Start

```bash
# Check if port is already in use
lsof -i :9090

# Try a different port
osxcleaner metrics start --port 9091
```

### No Cleanup Statistics

Cleanup statistics are only recorded when cleanup operations are performed. Run a cleanup to generate statistics:

```bash
osxcleaner clean --level light
osxcleaner metrics show
```

### Reset Statistics

```bash
osxcleaner metrics reset --force
```
