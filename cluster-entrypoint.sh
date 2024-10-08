#!/bin/bash

set -e

# Set the Erlang cookie from the environment variable if provided
if [ -n "$RABBITMQ_ERLANG_COOKIE" ]; then
    echo "$RABBITMQ_ERLANG_COOKIE" > /var/lib/rabbitmq/.erlang.cookie
fi

# Change .erlang.cookie permission
chmod 400 /var/lib/rabbitmq/.erlang.cookie

# Get hostname from environment variable
HOSTNAME=$(hostname)
echo "Starting RabbitMQ Server For host: $HOSTNAME"

# Start RabbitMQ server
if [ -z "$JOIN_CLUSTER_HOST" ]; then
    /usr/local/bin/docker-entrypoint.sh rabbitmq-server &
    sleep 5
    rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit\@$HOSTNAME.pid
else
    /usr/local/bin/docker-entrypoint.sh rabbitmq-server -detached
    sleep 5
    rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit\@$HOSTNAME.pid
    rabbitmqctl stop_app
    rabbitmqctl join_cluster rabbit@$JOIN_CLUSTER_HOST
    rabbitmqctl start_app
fi

# Define policy details
POLICY_NAME="ha-all"
POLICY_PATTERN="^consumer-[a-zA-Z0-9_-]+-operation$"
POLICY_DEFINITION='{"ha-mode": "all"}'
POLICY_PRIORITY=0

# Check if the policy already exists
POLICY_EXISTS=$(rabbitmqctl list_policies | grep "$POLICY_NAME" || true)

# Initialize policy if not exist
if [ -z "$POLICY_EXISTS" ]; then
  echo "Setting RabbitMQ policy $POLICY_NAME..."
  
  # Setting the policy using rabbitmqctl
  rabbitmqctl set_policy "$POLICY_NAME" "$POLICY_PATTERN" "$POLICY_DEFINITION" --priority "$POLICY_PRIORITY"
else
  echo "Policy $POLICY_NAME already exists. No changes made."
fi

# Keep foreground process active ...
tail -f /dev/null