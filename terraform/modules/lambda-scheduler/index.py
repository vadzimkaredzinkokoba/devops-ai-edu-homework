"""
ECS Service Scheduler Lambda Function

This function starts/stops ECS services based on EventBridge schedule rules.
Used for cost optimization by stopping services during non-business hours.
"""

import json
import os
import boto3
from datetime import datetime

# Initialize AWS clients
ecs = boto3.client('ecs')
cloudwatch = boto3.client('cloudwatch')


def handler(event, context):
    """
    Lambda handler to start or stop ECS services.
    
    Args:
        event: EventBridge event with 'action' field ('start' or 'stop')
        context: Lambda context object
        
    Returns:
        dict: Response with status code and message
    """
    
    # Get configuration from environment variables
    cluster_name = os.environ.get('CLUSTER_NAME')
    service_name = os.environ.get('SERVICE_NAME')
    region = os.environ.get('AWS_REGION', 'us-east-1')
    
    # Get action from event (default to stop for safety)
    action = event.get('action', 'stop')
    
    # Validate required environment variables
    if not cluster_name or not service_name:
        error_msg = "Missing required environment variables: CLUSTER_NAME, SERVICE_NAME"
        print(f"ERROR: {error_msg}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': error_msg})
        }
    
    # Determine desired task count based on action
    if action == 'start':
        desired_count = int(os.environ.get('DESIRED_COUNT', '2'))
    elif action == 'stop':
        desired_count = 0
    else:
        error_msg = f"Invalid action: {action}. Must be 'start' or 'stop'"
        print(f"ERROR: {error_msg}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': error_msg})
        }
    
    print(f"Action: {action}")
    print(f"Cluster: {cluster_name}")
    print(f"Service: {service_name}")
    print(f"Desired Count: {desired_count}")
    
    try:
        # Get current service status
        describe_response = ecs.describe_services(
            cluster=cluster_name,
            services=[service_name]
        )
        
        if not describe_response['services']:
            error_msg = f"Service {service_name} not found in cluster {cluster_name}"
            print(f"ERROR: {error_msg}")
            return {
                'statusCode': 404,
                'body': json.dumps({'error': error_msg})
            }
        
        current_service = describe_response['services'][0]
        current_desired = current_service['desiredCount']
        current_running = current_service['runningCount']
        
        print(f"Current state - Desired: {current_desired}, Running: {current_running}")
        
        # Update service desired count
        update_response = ecs.update_service(
            cluster=cluster_name,
            service=service_name,
            desiredCount=desired_count
        )
        
        new_desired = update_response['service']['desiredCount']
        
        # Log success
        success_msg = f"Service {service_name} updated: {current_desired} -> {new_desired} tasks"
        print(f"SUCCESS: {success_msg}")
        
        # Send custom CloudWatch metric
        send_cloudwatch_metric(
            cluster_name=cluster_name,
            service_name=service_name,
            action=action,
            desired_count=new_desired
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': success_msg,
                'cluster': cluster_name,
                'service': service_name,
                'action': action,
                'previous_desired_count': current_desired,
                'new_desired_count': new_desired,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except ecs.exceptions.ServiceNotFoundException:
        error_msg = f"Service {service_name} not found in cluster {cluster_name}"
        print(f"ERROR: {error_msg}")
        return {
            'statusCode': 404,
            'body': json.dumps({'error': error_msg})
        }
        
    except ecs.exceptions.ClusterNotFoundException:
        error_msg = f"Cluster {cluster_name} not found"
        print(f"ERROR: {error_msg}")
        return {
            'statusCode': 404,
            'body': json.dumps({'error': error_msg})
        }
        
    except Exception as e:
        error_msg = f"Unexpected error: {str(e)}"
        print(f"ERROR: {error_msg}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_msg})
        }


def send_cloudwatch_metric(cluster_name, service_name, action, desired_count):
    """
    Send custom CloudWatch metric for monitoring scheduler actions.
    
    Args:
        cluster_name: ECS cluster name
        service_name: ECS service name
        action: Action performed ('start' or 'stop')
        desired_count: New desired task count
    """
    try:
        cloudwatch.put_metric_data(
            Namespace='ECS/Scheduler',
            MetricData=[
                {
                    'MetricName': 'DesiredTaskCount',
                    'Dimensions': [
                        {
                            'Name': 'ClusterName',
                            'Value': cluster_name
                        },
                        {
                            'Name': 'ServiceName',
                            'Value': service_name
                        },
                        {
                            'Name': 'Action',
                            'Value': action
                        }
                    ],
                    'Value': desired_count,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
        print(f"CloudWatch metric sent: DesiredTaskCount={desired_count}")
    except Exception as e:
        print(f"WARNING: Failed to send CloudWatch metric: {str(e)}")
        # Don't fail the function if metric publishing fails
