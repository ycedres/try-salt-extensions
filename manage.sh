#!/usr/bin/env bash
set -e

ACTION="start"
REBUILD=false

usage() {
    echo "Usage: $0 [start|stop|restart|deploy|fix-keys] [--rebuild|-r]"
    echo ""
    echo "Commands:"
    echo "  start     Start the salt-master and salt-minion containers (default)"
    echo "  stop      Stop and remove the containers"
    echo "  restart   Restart the containers"
    echo "  deploy    Clear .pyc cache & restart salt-minion to reload host code"
    echo "  fix-keys  Clear PKI keys, restart minion, re-accept key, and verify connection"
    echo ""
    echo "Options:"
    echo "  --rebuild, -r   Force a clean rebuild of the Docker images before starting"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        start) ACTION="start"; shift ;;
        stop) ACTION="stop"; shift ;;
        restart) ACTION="restart"; shift ;;
        deploy) ACTION="deploy"; shift ;;
        fix-keys) ACTION="fix-keys"; shift ;;
        --rebuild|-r) REBUILD=true; shift ;;
        --help|-h) usage ;;
        *) echo "Error: Unknown argument '$1'"; usage ;;
    esac
done

case "$ACTION" in
    start)
        if [ "$REBUILD" = true ]; then
            echo "==> Rebuilding Docker images (no-cache)..."
            docker compose build --no-cache
        fi
        echo "==> Starting containers..."
        docker compose up -d
        ;;

    stop)
        echo "==> Stopping and removing containers..."
        docker compose down
        ;;

    restart)
        if [ "$REBUILD" = true ]; then
            echo "==> Rebuilding Docker images (no-cache)..."
            docker compose build --no-cache
        fi
        echo "==> Restarting containers..."
        docker compose down
        docker compose up -d
        ;;

    deploy)
        if [ "$REBUILD" = true ]; then
            echo "==> Rebuilding salt-minion image (no-cache)..."
            docker compose build --no-cache salt-minion
        fi
        echo "==> Cleaning cached .pyc files inside salt-minion..."
        docker exec salt-minion find /opt/saltstack/salt/extras-3.14/saltext/dockermod -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

        echo "==> Deploying code changes to salt-minion..."
        docker compose restart salt-minion
        ;;

    fix-keys)
        echo "==> Removing stale minion key from master..."
        docker exec salt-master salt-key -d salt-minion -y 2>/dev/null || true

        echo "==> Removing master public key from minion..."
        docker exec salt-minion rm -f /etc/salt/pki/minion/minion_master.pub 2>/dev/null || true

        echo "==> Restarting minion to initiate new key exchange..."
        docker compose restart salt-minion
        sleep 3

        echo "==> Accepting new minion key on master..."
        docker exec salt-master salt-key -a salt-minion -y

        echo "==> Verifying Salt connection..."
        docker exec salt-master salt 'salt-minion' test.ping
        ;;
esac
