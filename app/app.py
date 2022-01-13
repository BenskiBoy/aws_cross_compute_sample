import os

def lambda_handler(event, context):
    print(os.environ.get('TASK_CONFIG'))
    return True

if __name__ == '__main__':
    lambda_handler({}, {})