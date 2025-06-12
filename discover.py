import boto3
import json
from collections import defaultdict

# Initialize AWS clients
clients = {
    's3': boto3.client('s3'),
    'cloudfront': boto3.client('cloudfront'),
    'lambda': boto3.client('lambda'),
    'cognito': boto3.client('cognito-idp'),
    'dynamodb': boto3.client('dynamodb'),
    'apigateway': boto3.client('apigateway'),
    'iam': boto3.client('iam'),
    'ec2': boto3.client('ec2')
}

# === DISCOVERY PHASE ===
def discover_resources():
    data = {}

    data['S3Buckets'] = [bucket['Name'] for bucket in clients['s3'].list_buckets().get('Buckets', [])]

    # CloudFront
    cloudfront_info = []
    for dist in clients['cloudfront'].list_distributions().get('DistributionList', {}).get('Items', []):
        cloudfront_info.append({
            'Id': dist['Id'],
            'DomainName': dist['DomainName'],
            'Origins': [origin['DomainName'] for origin in dist['Origins']['Items']]
        })
    data['CloudFrontDistributions'] = cloudfront_info

    # Lambda
    data['LambdaFunctions'] = [fn['FunctionName'] for fn in clients['lambda'].list_functions().get('Functions', [])]

    # Cognito
    data['CognitoUserPools'] = [
        {'Name': pool['Name'], 'Id': pool['Id']}
        for pool in clients['cognito'].list_user_pools(MaxResults=50).get('UserPools', [])
    ]

    # DynamoDB
    data['DynamoDBTables'] = clients['dynamodb'].list_tables().get('TableNames', [])

    # API Gateway
    data['APIGatewayAPIs'] = [
        {'Name': api['name'], 'Id': api['id']}
        for api in clients['apigateway'].get_rest_apis().get('items', [])
    ]

    # IAM
    data['IAM'] = {
        'Users': [user['UserName'] for user in clients['iam'].list_users().get('Users', [])],
        'Roles': [role['RoleName'] for role in clients['iam'].list_roles().get('Roles', [])],
        'Policies': [policy['PolicyName'] for policy in clients['iam'].list_policies(Scope='Local').get('Policies', [])]
    }

    # Networking
    ec2 = clients['ec2']
    instances = [
        instance['InstanceId']
        for res in ec2.describe_instances().get('Reservations', [])
        for instance in res.get('Instances', [])
    ]
    data['Networking'] = {
        'VPCs': [vpc['VpcId'] for vpc in ec2.describe_vpcs().get('Vpcs', [])],
        'Subnets': [subnet['SubnetId'] for subnet in ec2.describe_subnets().get('Subnets', [])],
        'SecurityGroups': [sg['GroupName'] for sg in ec2.describe_security_groups().get('SecurityGroups', [])],
        'EC2Instances': instances
    }

    return data

# === VISUALIZATION PREP ===
def prepare_graph_data(discovery_data):
    edges = []
    nodes = set()

    for dist in discovery_data.get('CloudFrontDistributions', []):
        src = f"CloudFront:{dist['DomainName']}"
        nodes.add(src)
        for origin in dist['Origins']:
            dest = f"Origin:{origin}"
            nodes.add(dest)
            edges.append((src, dest))

    for api in discovery_data.get('APIGatewayAPIs', []):
        src = f"API:{api['Name']}"
        nodes.add(src)
        for fn in discovery_data.get('LambdaFunctions', []):
            dest = f"Lambda:{fn}"
            nodes.add(dest)
            edges.append((src, dest))

    return {'nodes': list(nodes), 'edges': edges}

# === ANALYSIS PHASE ===
def analyze_infrastructure(graph_data):
    analysis = defaultdict(list)
    for src, dest in graph_data['edges']:
        analysis[src].append(dest)
    return dict(analysis)

# === RUN ===
if __name__ == "__main__":
    discovery = discover_resources()
    graph_data = prepare_graph_data(discovery)
    analysis = analyze_infrastructure(graph_data)

    # Save or print output
    print(json.dumps({
        'DiscoverySummary': discovery,
        'GraphStructure': graph_data,
        'AnalysisReport': analysis
    }, indent=2))

