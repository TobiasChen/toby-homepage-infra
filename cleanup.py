import os
import shutil
path = './generated/aws/'


print(os.stat('./generated/aws/qldb/us-east-1/resources.tf').st_size, os.stat('./generated/aws/qldb/eu-central-1/resources.tf').st_size)
print(os.stat('./generated/aws/s3/us-east-1/resources.tf').st_size, os.stat('./generated/aws/s3/eu-central-1/resources.tf').st_size)
existing = []
empty = []
for root, dirs, files in os.walk(path):
    for directory in dirs:
        if directory == "eu-central-1" or directory == "us-east-1":
            continue
        resource1 = path + directory + "/us-east-1" +"/resources.tf"
        resource2 = path + directory + "/eu-central-1" +"/resources.tf"
        print(resource1, resource2)
        if(os.stat(resource1).st_size > 1 or os.stat(resource2).st_size > 1):
            existing.append(directory)
        else:
            shutil.rmtree(path + directory, ignore_errors=False, onerror=None)
        
print("Existing", existing)
print("Empty", empty)