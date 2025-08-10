# Zammad Scheduler Runbook

## Overview
This runbook provides troubleshooting steps for Zammad scheduler issues, particularly the problem described in GitHub issue #5718 where the scheduler fails to properly resume operations after database connectivity issues.

## Common Alerts and Resolutions

### ZammadSchedulerDown
**Severity**: Critical  
**Description**: The Zammad scheduler pod is not running.

**Immediate Actions**:
1. Check pod status: `kubectl get pods -n default -l app.kubernetes.io/component=zammad-scheduler`
2. Check pod logs: `kubectl logs -n default -l app.kubernetes.io/component=zammad-scheduler --tail=100`
3. Check recent events: `kubectl describe pod -n default -l app.kubernetes.io/component=zammad-scheduler`

**Resolution**:
- If pod is in CrashLoopBackOff, check logs for errors
- If pod is Pending, check node resources and scheduling constraints
- If pod is missing, check HelmRelease status: `kubectl get helmrelease -n default zammad`

### ZammadSchedulerDatabaseDisconnected
**Severity**: Critical  
**Description**: The scheduler cannot connect to the database.

**Immediate Actions**:
1. Test database connectivity: 
   ```bash
   kubectl exec -n default -l app.kubernetes.io/component=zammad-scheduler -- \
     bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1')"
   ```
2. Check PostgreSQL cluster status:
   ```bash
   kubectl get cluster -n database postgres16
   kubectl get pods -n database -l cnpg.io/cluster=postgres16
   ```

**Resolution**:
- If database is down, investigate PostgreSQL cluster issues
- If database is up but unreachable, check network policies and DNS resolution
- The liveness probe should automatically restart the scheduler pod after 10 minutes

### ZammadSchedulerEmailProcessingStalled
**Severity**: Critical  
**Description**: No emails have been processed for more than 30 minutes.

**Immediate Actions**:
1. Check email processing jobs:
   ```bash
   kubectl exec -n default -l app.kubernetes.io/component=zammad-scheduler -- \
     bundle exec rails runner "puts Delayed::Job.where('handler LIKE ?', '%Channel::EmailParser%').count"
   ```
2. Check for failed email jobs:
   ```bash
   kubectl exec -n default -l app.kubernetes.io/component=zammad-scheduler -- \
     bundle exec rails runner "puts Delayed::Job.where.not(failed_at: nil).where('handler LIKE ?', '%Channel::EmailParser%').count"
   ```

**Resolution**:
- Restart the scheduler pod: `kubectl delete pod -n default -l app.kubernetes.io/component=zammad-scheduler`
- Check email channel configuration in Zammad admin interface
- Verify SMTP/IMAP settings are correct

### ZammadSchedulerRestarted
**Severity**: Warning  
**Description**: The scheduler pod has restarted, possibly due to database connectivity issues.

**Investigation Steps**:
1. Check restart reason: `kubectl describe pod -n default -l app.kubernetes.io/component=zammad-scheduler`
2. Check previous logs: `kubectl logs -n default -l app.kubernetes.io/component=zammad-scheduler -p`
3. Monitor for pattern of restarts indicating ongoing issues

## Monitoring Metrics

### Key Metrics to Monitor
- `zammad_scheduler_up`: Scheduler availability (should be 1)
- `zammad_scheduler_database_connected`: Database connectivity (should be 1)
- `zammad_scheduler_pending_jobs`: Number of pending jobs (monitor for growth)
- `zammad_scheduler_failed_jobs`: Number of failed jobs (should be low)
- `zammad_scheduler_last_email_processed_seconds`: Time since last email processed
- `zammad_scheduler_unprocessed_emails`: Number of unprocessed emails

### Grafana Dashboard Queries
```promql
# Scheduler uptime
up{job="zammad-scheduler"}

# Database connectivity
zammad_scheduler_database_connected

# Job processing rate
rate(zammad_scheduler_pending_jobs[5m])

# Email processing latency
zammad_scheduler_last_email_processed_seconds

# Pod restart rate
rate(kube_pod_container_status_restarts_total{namespace="default", pod=~"zammad-scheduler-.*"}[1h])
```

## Preventive Measures

### Database Connection Resilience
- The liveness probe tests database connectivity every 5 minutes
- Pod will restart if database connection fails for more than 10 minutes
- Monitor `ZammadSchedulerDatabaseDisconnected` alerts

### Resource Monitoring
- Monitor memory and CPU usage to prevent resource exhaustion
- Elasticsearch has been configured with 8GB memory to prevent restarts
- Watch for `ZammadSchedulerHighMemoryUsage` and `ZammadSchedulerHighCPUUsage` alerts

### Email Processing Monitoring
- `ZammadSchedulerEmailProcessingStalled` alert triggers if no emails processed for 30 minutes
- `ZammadSchedulerUnprocessedEmails` alert triggers if more than 10 emails are queued for 10 minutes

## Emergency Procedures

### Complete Scheduler Recovery
If the scheduler is completely stuck:
```bash
# 1. Restart the scheduler pod
kubectl delete pod -n default -l app.kubernetes.io/component=zammad-scheduler

# 2. Wait for pod to restart and check status
kubectl get pods -n default -l app.kubernetes.io/component=zammad-scheduler -w

# 3. Verify database connectivity
kubectl exec -n default -l app.kubernetes.io/component=zammad-scheduler -- \
  bundle exec rails runner "puts 'DB OK: ' + ActiveRecord::Base.connection.execute('SELECT version()').first['version']"

# 4. Check job processing
kubectl logs -n default -l app.kubernetes.io/component=zammad-scheduler --tail=50
```

### Database Connection Issues
If database connectivity is the root cause:
```bash
# 1. Check PostgreSQL cluster health
kubectl get cluster -n database postgres16
kubectl get pods -n database -l cnpg.io/cluster=postgres16

# 2. Test connectivity from scheduler
kubectl exec -n default -l app.kubernetes.io/component=zammad-scheduler -- \
  nc -zv postgres16-rw.database.svc.cluster.local 5432

# 3. Check DNS resolution
kubectl exec -n default -l app.kubernetes.io/component=zammad-scheduler -- \
  nslookup postgres16-rw.database.svc.cluster.local
```

## Related Documentation
- [GitHub Issue #5718](https://github.com/zammad/zammad/issues/5718)
- [Zammad Helm Chart Documentation](https://github.com/zammad/zammad-helm)
- [PostgreSQL CNPG Operator Documentation](https://cloudnative-pg.io/documentation/)
