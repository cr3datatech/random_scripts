#!/bin/bash

######################################
# 1. List S3 Buckets and Save to File
######################################

aws s3 ls | awk '{print $3 }' > buckets.txt
BUCKET_FILE="buckets.txt"
date=`date +%Y-%m-%d`
output_file="s3_bucket_sizes"

# The script uses the AWS CLI command aws s3 ls to list all the S3 buckets in the account.
# The awk '{print $3 }' extracts only the bucket names (since the third column in the output corresponds to the bucket name).
# These bucket names are stored in a file called buckets.txt.
# date captures the current date in the format, which is later used in the log filename.
# output_file is a variable that will store the base name for the output log files.

###############################################
# 2.  Iterate Over Each Bucket and List Folders
###############################################

while read -r S3_BUCKET; do
    folders=$(aws s3 ls "s3://$S3_BUCKET/" | grep PRE | awk '{print $2}' | sort -u)
    for folder in $folders; do

# This part of the script reads each S3 bucket name from buckets.txt.
# For each bucket, it lists the "folders" (technically S3 doesn't have real folders, but prefixes are treated like folders).
# The aws s3 ls "s3://$S3_BUCKET/" lists the contents of the bucket.
# grep PRE filters for lines representing folders (since AWS S3 is used PRE to denote folder prefixes).
# awk '{print $2}' extracts the folder names (prefixes) from the command output.
# sort -u ensures the list of folder names is unique.

#####################################
# 3. Sanitize Bucket and Folder Names
#####################################

        sanitized_bucket_name=$(echo "$S3_BUCKET" | tr / _)
        sanitized_folder_name=$(echo "$folder" | tr / _)

        bucket_filename="${sanitized_bucket_name}.txt"
        folder_filename="${sanitized_bucket_name}_${sanitized_folder_name}.txt"

# Since bucket and folder names may contain slashes (/), which are not suitable for file names, tr / _ is used to replace slashes with underscores (_) in both the bucket and folder names.
# This creates sanitized bucket and folder names.
# bucket_filename and folder_filename are the text files where the script will store size information. Each bucket and its corresponding folders will have their unique filename based on these sanitized names.

######################################
# 4. Calculate the Size of Each Folder
######################################

        echo "s3://$S3_BUCKET/$folder"
        aws s3 ls "s3://$S3_BUCKET/$folder" --recursive --human-readable --summarize >> "$folder_filename"
    done
done < "$BUCKET_FILE" 

# For each folder in the bucket, the script prints the full path to the folder (for debugging or informational purposes).
# Then, the aws s3 ls command is used to recursively list all the contents of the folder and calculate the total size.
# --recursive: Lists all objects in the folder, including any subfolders.
# --human-readable: Displays sizes in a human-readable format (e.g., MB, GB).
# --summarize: Shows a summary of the total size and number of objects in the folder.
# The output is appended to the corresponding folder_filename.

###############################
# 5. Pause and Aggregate Output
###############################

sleep 10
grep " Total Size:" * > "${output_file}_${date}.log"

# The script pauses for 10 seconds (sleep 10) to ensure all files are written correctly.
# It then uses grep " Total Size:" * to extract the total size information from all the files created so far.
# The result is written into a single log file named s3_bucket_YYYY-MM-DD.log, where YYYY-MM-DD is the current date.

############################################
# 6. Prepare for Deletion of Temporary Files
############################################

sleep 10
grep " Total Size:" * | awk -F":" '{print$1}' > deletion

# After another 10-second pause, the script gathers the names of all files that contain "Total Size:" (the summary files) and extracts the filenames using awk -F":" '{print$1}'.
# This list of filenames is saved into a file called deletion.

#############################
# 7. Clean Up Temporary Files
#############################

grep -v -E "calculate_aws_s3_object_size.sh|^${output_file}" deletion > deletion.tmp && mv deletion.tmp deletion
sed 's/^/rm -rf /' deletion > delete_file && sh delete_file

# The script uses sed to prepend each line in the deletion file with the command rm -rf, effectively creating a file named delete_file that contains the necessary commands to delete the temporary text files generated during the process.
# Finally, sh delete_file executes the deletion of all the temporary files, leaving only the final log files and the script itself.

#######Script End#########