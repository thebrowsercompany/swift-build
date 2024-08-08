from google.cloud import bigquery

BQ_SCHEMA = [
  bigquery.SchemaField("toolchain_version", "STRING", mode="REQUIRED"),
  bigquery.SchemaField("creation_time", "TIMESTAMP", mode="REQUIRED"),
  bigquery.SchemaField("target_os", "STRING", mode="REQUIRED"),
  bigquery.SchemaField("target_arch", "STRING", mode="REQUIRED"),
  bigquery.SchemaField("filename", "STRING", mode="REQUIRED"),
  bigquery.SchemaField("segment", "STRING", mode="REQUIRED"),
  bigquery.SchemaField("filesize", "INTEGER", mode="REQUIRED"),
  bigquery.SchemaField("vmsize", "INTEGER", mode="REQUIRED"),
]
