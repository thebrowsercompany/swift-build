# Uploads a csv file containing binary size data to BigQuery
#
# This script uses Google Cloud's application default credentials. To
# Authenticate with Google Cloud in CI: place a service account
# credentials file at the path identified in the environment variable
# GOOGLE_APPLICATION_CREDENTIALS. To authenticate as a User, run:
# `gcloud auth application-default login`.
#
# For more infomaration on application default credentials, see
# https://cloud.google.com/docs/authentication/application-default-credentials

import os
import sys
from google.cloud import bigquery
from bigquery_schema import BQ_SCHEMA

GCS_PROJECT_ID = "bcny-arc-server"
BQ_DATASET = "ci_data"
BQ_TABLE = "swift_toolchain_binary_sizes"


def bigquery_load_csv(client, dataset_id, table_id, csv_file, schema):
  job_config = bigquery.LoadJobConfig(
    source_format=bigquery.SourceFormat.CSV,
    skip_leading_rows=1,
    allow_quoted_newlines=True,
    schema=schema,
    write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
  )

  table_ref = client.dataset(dataset_id).table(table_id)
  with open(csv_file, 'rb') as csv_file:
    load_job = client.load_table_from_file(csv_file,
                                           table_ref,
                                           job_config=job_config)

  print(f"Starting job {load_job.job_id}")
  load_job.result()  # Wait for table load to complete.
  print(f"Job finished. Loaded {load_job.output_rows} rows to {dataset_id}:{table_id}.")


def main():
    if len(sys.argv) != 2:
        sys.exit(os.EX_USAGE)

    csv_file = sys.argv[1]
    bq_client = bigquery.Client(project=GCS_PROJECT_ID)
    bigquery_load_csv(bq_client,
                      dataset_id=BQ_DATASET,
                      table_id=BQ_TABLE,
                      schema=BQ_SCHEMA,
                      csv_file=csv_file)

main()
