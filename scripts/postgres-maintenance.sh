#!/bin/bash
# PostgreSQL Maintenance Script for Disk Space Management
# Usage: ./postgres-maintenance.sh [check|cleanup|vacuum|all]

set -euo pipefail

NAMESPACE="database"
CLUSTER_NAME="postgres16"
PRIMARY_POD=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Find the primary PostgreSQL pod
find_primary_pod() {
    log "Finding primary PostgreSQL pod..."
    PRIMARY_POD=$(kubectl get pods -n $NAMESPACE -l cnpg.io/cluster=$CLUSTER_NAME,cnpg.io/instanceRole=primary -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$PRIMARY_POD" ]]; then
        # Fallback: find any running postgres pod
        PRIMARY_POD=$(kubectl get pods -n $NAMESPACE -l cnpg.io/cluster=$CLUSTER_NAME -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')
    fi
    
    if [[ -z "$PRIMARY_POD" ]]; then
        error "No running PostgreSQL pods found in cluster $CLUSTER_NAME"
        exit 1
    fi
    
    success "Using PostgreSQL pod: $PRIMARY_POD"
}

# Check disk space usage
check_disk_space() {
    log "Checking disk space usage..."
    
    echo "=== Disk Space Overview ==="
    kubectl exec -n $NAMESPACE $PRIMARY_POD -- df -h /var/lib/postgresql/data
    
    echo -e "\n=== WAL Directory Usage ==="
    kubectl exec -n $NAMESPACE $PRIMARY_POD -- du -sh /var/lib/postgresql/data/pgdata/pg_wal
    
    echo -e "\n=== Database Size ==="
    kubectl exec -n $NAMESPACE $PRIMARY_POD -- psql -U postgres -c "
        SELECT 
            datname,
            pg_size_pretty(pg_database_size(datname)) as size
        FROM pg_database 
        WHERE datname NOT IN ('template0', 'template1', 'postgres')
        ORDER BY pg_database_size(datname) DESC;
    "
    
    echo -e "\n=== WAL Settings ==="
    kubectl exec -n $NAMESPACE $PRIMARY_POD -- psql -U postgres -c "
        SELECT name, setting, unit, short_desc 
        FROM pg_settings 
        WHERE name IN ('max_wal_size', 'min_wal_size', 'wal_keep_size', 'archive_mode', 'archive_timeout')
        ORDER BY name;
    "
    
    echo -e "\n=== Archive Status ==="
    kubectl exec -n $NAMESPACE $PRIMARY_POD -- psql -U postgres -c "
        SELECT 
            archived_count,
            last_archived_wal,
            last_archived_time,
            failed_count,
            last_failed_wal,
            last_failed_time,
            stats_reset
        FROM pg_stat_archiver;
    "
}

# Clean up old WAL files (if archiving is working)
cleanup_wal_files() {
    log "Checking WAL cleanup status..."
    
    # Check if archiving is working
    local failed_count=$(kubectl exec -n $NAMESPACE $PRIMARY_POD -- psql -U postgres -t -c "SELECT failed_count FROM pg_stat_archiver;" | tr -d ' ')
    
    if [[ "$failed_count" -gt 0 ]]; then
        warn "Archive failures detected ($failed_count). Manual WAL cleanup may be risky."
        warn "Please check archive configuration before proceeding."
        return 1
    fi
    
    log "Triggering WAL checkpoint to clean up old files..."
    kubectl exec -n $NAMESPACE $PRIMARY_POD -- psql -U postgres -c "CHECKPOINT;"
    
    success "Checkpoint completed. Old WAL files should be cleaned up automatically."
}

# Run VACUUM on all databases
vacuum_databases() {
    log "Running VACUUM on all user databases..."
    
    # Get list of user databases
    local databases=$(kubectl exec -n $NAMESPACE $PRIMARY_POD -- psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres');" | tr -d ' ')
    
    for db in $databases; do
        if [[ -n "$db" ]]; then
            log "Vacuuming database: $db"
            kubectl exec -n $NAMESPACE $PRIMARY_POD -- psql -U postgres -d "$db" -c "VACUUM ANALYZE;"
        fi
    done
    
    success "VACUUM completed on all databases"
}

# Check cluster health
check_cluster_health() {
    log "Checking PostgreSQL cluster health..."
    
    echo "=== Cluster Status ==="
    kubectl get cluster $CLUSTER_NAME -n $NAMESPACE
    
    echo -e "\n=== Pod Status ==="
    kubectl get pods -n $NAMESPACE -l cnpg.io/cluster=$CLUSTER_NAME
    
    echo -e "\n=== PVC Status ==="
    kubectl get pvc -n $NAMESPACE | grep $CLUSTER_NAME
    
    echo -e "\n=== Recent Events ==="
    kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$CLUSTER_NAME --sort-by='.lastTimestamp' | tail -10
}

# Main function
main() {
    local action=${1:-"check"}
    
    log "Starting PostgreSQL maintenance - Action: $action"
    
    find_primary_pod
    
    case $action in
        "check")
            check_disk_space
            check_cluster_health
            ;;
        "cleanup")
            cleanup_wal_files
            ;;
        "vacuum")
            vacuum_databases
            ;;
        "all")
            check_disk_space
            check_cluster_health
            cleanup_wal_files
            vacuum_databases
            ;;
        *)
            error "Unknown action: $action"
            echo "Usage: $0 [check|cleanup|vacuum|all]"
            exit 1
            ;;
    esac
    
    success "Maintenance completed successfully"
}

# Run main function with all arguments
main "$@"
