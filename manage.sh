#!/usr/bin/env bash
set -e

# Default action is start
ACTION="start"
REBUILD=false

usage() {
    echo "Usage: $0 [start|stop|restart] [--rebuild|-r]"
    echo ""
    echo "Commands:"
    echo "  start     Start the salt-master and salt-minion containers (default)"
    echo "  stop      Stop and remove the containers"
    echo "  restart   Restart the containers"
    echo ""
    echo "Options:"
    echo "  --rebuild, -r   Force a clean rebuild of the Docker images before starting"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        start)
            ACTION="start"
            shift
            ;;
        stop)
            ACTION="stop"
            shift
            ;;
        restart)
            ACTION="restart"
            shift
            ;;
        --rebuild|-r)
            REBUILD=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Error: Unknown argument '$1'"
            usage
            ;;
    esac
done

# Main Execution Logic
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
esac
