# Zammad Scheduler Monitoring Solution

## Overview
This document describes the comprehensive monitoring and alerting solution implemented to prevent silent Zammad scheduler failures, particularly the issue described in GitHub issue #5718 where the scheduler fails to resume operations after database connectivity issues.

## Components Implemented

### 1. Health Monitoring (`monitoring-configmap.yaml`)
- **Custom metrics exporter sidecar** running alongside the scheduler
- **Exposes detailed metrics** about job processing, database connectivity, and email handling
- **Metrics endpoint**: `http://zammad-scheduler-metrics:9090/metrics`

**Key Metrics**:
- `zammad_scheduler_up`: Basic scheduler availability
- `zammad_scheduler_database_connected`: Database connectivity status
- `zammad_scheduler_pending_jobs`: Number of jobs waiting to be processed
- `zammad_scheduler_failed_jobs`: Number of failed jobs
- `zammad_scheduler_unprocessed_emails`: Unprocessed email count
- `zammad_scheduler_last_email_processed_seconds`: Time since last email processed
- `zammad_scheduler_pending_tickets`: Number of pending tickets
- `zammad_scheduler_last_ticket_processed_seconds`: Time since last ticket processed

### 2. Prometheus Integration (`servicemonitor.yaml`)
- **ServiceMonitor** for automatic metrics discovery by Prometheus
- **Service** exposing metrics endpoint for scraping
- **30-second scrape interval** for timely detection of issues

### 3. Proactive Alerting (`prometheusrules.yaml`)
Comprehensive alert rules covering:

**Critical Alerts**:
- `ZammadSchedulerDown`: Scheduler pod is not running (2min threshold)
- `ZammadSchedulerDatabaseDisconnected`: Database connectivity lost (1min threshold)
- `ZammadSchedulerEmailProcessingStalled`: No emails processed for 30+ minutes

**Warning Alerts**:
- `ZammadSchedulerJobQueueBacklog`: Large job queue backlog (100+ jobs for 5min)
- `ZammadSchedulerJobFailures`: Increasing job failures (5+ in 5min)
- `ZammadSchedulerUnprocessedEmails`: High unprocessed email count (10+ for 10min)
- `ZammadSchedulerTicketProcessingStalled`: No tickets processed for 1+ hour
- `ZammadSchedulerRestarted`: Pod restart detection (immediate notification)
- `ZammadSchedulerHighMemoryUsage`: Memory usage >90% for 5min
- `ZammadSchedulerHighCPUUsage`: CPU usage >90% for 10min

**Infrastructure Alerts**:
- `ZammadElasticsearchDown`: Elasticsearch unavailable
- `ZammadRedisDown`: Redis unavailable
- `ZammadDatabaseConnectionIssues`: High database rollback rate

### 4. Operational Dashboard (`grafana-dashboard.yaml`)
Grafana dashboard with panels for:
- **Scheduler Status**: Real-time up/down and database connectivity status
- **Job Queue Status**: Pending and failed job trends
- **Email Processing**: Unprocessed emails and processing latency
- **Ticket Processing**: Pending tickets and processing latency
- **Pod Restarts**: Restart frequency monitoring
- **Resource Usage**: Memory and CPU utilization

### 5. Redundancy Safeguards
**Multiple Scheduler Replicas**:
- Configured 2 scheduler replicas for high availability
- Zammad handles active/standby internally
- Provides automatic failover if primary scheduler fails

**Backup Email Processor** (`backup-processor.yaml`):
- CronJob running every 5 minutes
- Monitors main scheduler health
- Processes critical email jobs if main scheduler is unhealthy
- Prevents email processing from completely stopping

### 6. Enhanced Liveness Probe
- **Database connectivity test** every 5 minutes
- **Automatic pod restart** if database connection cannot be recovered
- **Conservative thresholds**: 2-minute initial delay, 10-minute failure window

## Alert Routing
Alerts are routed through your existing AlertManager configuration:
- **Critical alerts**: Sent to Discord webhook immediately
- **Warning alerts**: Sent to Discord with grouping (5min intervals)
- **Inhibition rules**: Critical alerts suppress related warnings

## Accessing Monitoring

### Grafana Dashboard
1. Navigate to `https://grafana.${SECRET_DOMAIN}`
2. Look for "Zammad Scheduler Monitoring" dashboard
3. Monitor real-time scheduler health and performance

### Prometheus Metrics
1. Navigate to `https://prometheus.${SECRET_DOMAIN}`
2. Query metrics like `zammad_scheduler_up` or `zammad_scheduler_database_connected`
3. Set up custom alerts if needed

### UptimeKuma Integration
Your existing UptimeKuma can monitor:
- Zammad web interface availability
- Scheduler metrics endpoint health
- Email processing endpoint (if exposed)

## Deployment Instructions

1. **Apply the monitoring configuration**:
   ```bash
   kubectl apply -k kubernetes/apps/zammad/app/
   ```

2. **Verify ServiceMonitor is discovered**:
   ```bash
   kubectl get servicemonitor -n default zammad-scheduler
   ```

3. **Check Prometheus targets**:
   - Go to Prometheus UI → Status → Targets
   - Look for `zammad-scheduler` target

4. **Verify alerts are loaded**:
   ```bash
   kubectl get prometheusrule -n default zammad-scheduler-alerts
   ```

5. **Import Grafana dashboard**:
   - Dashboard should auto-import via ConfigMap
   - Check Grafana UI for "Zammad Scheduler Monitoring"

## Testing the Solution

### Simulate Database Connectivity Issue
```bash
# Temporarily block database access to test alerts
kubectl exec -n default -l app.kubernetes.io/component=zammad-scheduler -- \
  iptables -A OUTPUT -d postgres16-rw.database.svc.cluster.local -j DROP

# Wait for alerts to trigger (should see ZammadSchedulerDatabaseDisconnected)
# Restore connectivity
kubectl delete pod -n default -l app.kubernetes.io/component=zammad-scheduler
```

### Verify Email Processing Monitoring
```bash
# Check current email processing metrics
kubectl exec -n default -l app.kubernetes.io/component=zammad-scheduler -- \
  curl -s localhost:9090/metrics | grep zammad_scheduler_last_email_processed
```

## Maintenance

### Regular Checks
- Monitor Grafana dashboard weekly for trends
- Review failed job counts and investigate patterns
- Check alert firing frequency and adjust thresholds if needed

### Troubleshooting
- See `docs/runbooks/zammad-scheduler.md` for detailed troubleshooting steps
- Use Prometheus queries to investigate metric anomalies
- Check AlertManager for alert routing issues

## Benefits

1. **Proactive Detection**: Issues detected within 1-5 minutes instead of hours
2. **Automatic Recovery**: Liveness probe ensures automatic pod restart for DB issues
3. **Redundancy**: Multiple scheduler replicas and backup processor prevent complete failure
4. **Operational Visibility**: Real-time dashboards and metrics for quick diagnosis
5. **Historical Tracking**: Prometheus retention allows trend analysis and capacity planning
