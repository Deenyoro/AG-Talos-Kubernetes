# Zammad Scheduler Comprehensive Monitoring and Recovery Runbook

## Overview

This runbook covers the comprehensive monitoring and recovery system for the Zammad scheduler, designed to prevent silent failures and ensure reliable job processing for email notifications and Discord alerts.

## Architecture

### Monitoring Components

1. **Job Queue Monitor** (`zammad-job-queue-monitor`)
   - Exposes detailed metrics about job processing
   - Monitors queue health, processing rates, and stuck jobs
   - Provides Prometheus metrics for alerting

2. **Enhanced Liveness Probe**
   - Tests database connectivity
   - Detects jobs stuck for >15 minutes
   - Prevents excessive job backlog (>200 jobs)

3. **Automatic Recovery System** (`zammad-scheduler-recovery`)
   - Monitors job queue health continuously
   - Automatically restarts scheduler when issues detected
   - Rate-limited to prevent restart loops

4. **Comprehensive Alerting**
   - Multiple alert levels (Critical, Warning, Info)
   - Covers job processing, dependencies, and resource usage

## Alert Response Guide

### Critical Alerts (Immediate Action Required)

#### ZammadJobQueueBacklog
**Trigger**: >50 pending jobs for 2+ minutes
**Impact**: Delayed email notifications and Discord alerts
**Response**:
1. Check scheduler pod status: `kubectl get pods -n default -l app.kubernetes.io/component=zammad-scheduler`
2. Check job queue: `kubectl exec -n default deployment/zammad-railsserver -- bundle exec rails runner "puts Delayed::Job.where(failed_at: nil).count"`
3. If automatic recovery hasn't triggered, manually restart: `kubectl delete pod -n default -l app.kubernetes.io/component=zammad-scheduler`

#### ZammadJobsStuckTooLong
**Trigger**: >5 jobs pending for >10 minutes
**Impact**: Critical notifications not being sent
**Response**:
1. Immediate scheduler restart (automatic recovery should handle this)
2. Check for database connectivity issues
3. Monitor job processing after restart

#### ZammadSchedulerUnresponsive
**Trigger**: Health monitoring system cannot query job queue
**Impact**: Complete scheduler failure
**Response**:
1. Check scheduler pod logs: `kubectl logs -n default -l app.kubernetes.io/component=zammad-scheduler`
2. Check database connectivity
3. Restart scheduler pod immediately

#### ZammadJobProcessingStalled
**Trigger**: <0.1 jobs/minute with >10 pending jobs for 5+ minutes
**Impact**: Scheduler appears running but not processing jobs
**Response**:
1. This is the exact issue we experienced - scheduler restart required
2. Check scheduler logs for stuck processes
3. Automatic recovery should handle this

### Warning Alerts (Monitor and Investigate)

#### ZammadJobFailuresHigh
**Trigger**: >20 failed jobs for 5+ minutes
**Response**:
1. Check failed job details: `kubectl exec -n default deployment/zammad-railsserver -- bundle exec rails runner "Delayed::Job.where.not(failed_at: nil).order(failed_at: :desc).limit(5).each {|j| puts j.last_error}"`
2. Look for patterns in failures (email server issues, webhook problems)
3. Consider clearing failed jobs if they're due to temporary issues

#### ZammadNotificationJobsPending
**Trigger**: >10 notification jobs pending for 3+ minutes
**Response**:
1. Check Discord webhook connectivity
2. Verify email server connectivity
3. Monitor for escalation to critical alerts

### Info Alerts (Tracking Only)

#### ZammadSchedulerRestarted
**Purpose**: Track scheduler restarts for pattern analysis
**Response**: Log and monitor frequency

## Manual Troubleshooting

### Check Job Queue Health
```bash
kubectl exec -n default deployment/zammad-railsserver -- bundle exec rails runner "
puts 'Job Queue Status:'
puts \"Pending: #{Delayed::Job.where(failed_at: nil, locked_at: nil).where('run_at <= ?', Time.now).count}\"
puts \"Locked: #{Delayed::Job.where.not(locked_at: nil).count}\"
puts \"Failed: #{Delayed::Job.where.not(failed_at: nil).count}\"
puts \"Old Pending: #{Delayed::Job.where(failed_at: nil, locked_at: nil).where('run_at <= ?', Time.now - 600).count}\"
"
```

### Check Scheduler Logs
```bash
kubectl logs -n default -l app.kubernetes.io/component=zammad-scheduler --tail=100
```

### Check Recovery System Status
```bash
kubectl logs -n default -l app.kubernetes.io/component=scheduler-recovery --tail=50
```

### Manual Scheduler Restart
```bash
kubectl delete pod -n default -l app.kubernetes.io/component=zammad-scheduler
```

### Check Job Processing Rate
```bash
kubectl exec -n default deployment/zammad-railsserver -- bundle exec rails runner "
recent = Delayed::Job.where('updated_at > ?', Time.now - 300).count
puts \"Jobs processed in last 5 minutes: #{recent}\"
puts \"Processing rate: #{recent / 5.0} jobs/minute\"
"
```

## Monitoring Dashboards

### Prometheus Metrics
- `zammad_job_queue_pending_jobs` - Current pending jobs
- `zammad_job_queue_old_pending_jobs` - Jobs stuck >10 minutes
- `zammad_job_processing_rate` - Jobs processed per minute
- `zammad_scheduler_responsive` - Health check status

### Grafana Dashboard
Access the Zammad Scheduler Monitoring dashboard at `https://grafana.${SECRET_DOMAIN}`

## Recovery System Configuration

### Automatic Recovery Triggers
- Scheduler unresponsive (1 minute)
- >100 pending jobs (immediate)
- >10 jobs stuck >10 minutes (immediate)
- >20 pending jobs with <0.1 processing rate (5 minutes)

### Rate Limiting
- Maximum 3 restarts per hour
- 5-minute cooldown between restarts
- Prevents restart loops

## Preventive Measures

### Enhanced Liveness Probe
- Checks database connectivity every 5 minutes
- Detects job processing issues
- Automatically restarts pod when problems detected

### Continuous Monitoring
- Job queue metrics updated every 30 seconds
- Alerts fire within 1-5 minutes of issues
- Automatic recovery typically resolves issues within 2-3 minutes

## Escalation

If automatic recovery fails or alerts continue:
1. Check database and Redis connectivity
2. Review Elasticsearch status
3. Check resource constraints (CPU, memory)
4. Consider manual intervention or infrastructure issues

## Testing

### Simulate Job Backlog
```bash
kubectl exec -n default deployment/zammad-railsserver -- bundle exec rails runner "
50.times do |i|
  Delayed::Job.enqueue(TestJob.new, run_at: Time.now - 1.hour)
end
puts 'Created 50 old jobs for testing'
"
```

### Test Recovery System
Monitor logs and verify automatic restart triggers when thresholds are exceeded.

## Maintenance

### Regular Tasks
- Review failed jobs weekly
- Monitor restart frequency
- Update alert thresholds based on usage patterns
- Test recovery system monthly
