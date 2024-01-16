terraform {
  required_version = ">= 1.6"

  required_providers {
	google = ">= 5.10"
  }
}

provider "google" {
  project = "${var.project_id}"
}

# DB
resource "google_sql_database_instance" "song" {
    name     = "song"
    database_version = "POSTGRES_15"
    region = "${var.region}"
    settings {
        tier = "db-f1-micro"
    }
    deletion_protection = false
}

# resource "google_sql_database" "postgresql_db" {
#   name      = "postgres"
#   instance  = "${google_sql_database_instance.song.name}"
# }

resource "google_sql_user" "postgresql_user" {
  name     = "postgres"
  instance = "${google_sql_database_instance.song.name}"
  password = "postgres"
}

resource "google_project_service" "sqladmin_api" {
  service            = "sqladmin.googleapis.com"
}

#cloud run
resource "google_cloud_run_v2_service" "gcp-lyrics-app" {
  name     = "gcp-lyrics-app"
  location = "${var.region}"

  template {
    containers {
      image = "gcr.io/${var.project_id}/app"

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.song.connection_name]
      }
    }
  }
  client     = "terraform"
  depends_on = [google_project_service.cloudrun_api, google_project_service.sqladmin_api]
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_v2_service.gcp-lyrics-app.location
  project     = google_cloud_run_v2_service.gcp-lyrics-app.project
  service     = google_cloud_run_v2_service.gcp-lyrics-app.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_project_service" "cloudrun_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}


# cloud function

resource "google_storage_bucket" "cloud-function-bucket" {
  name = "cloud-function-bucket-${var.project_id}"
  location = "us-central1"
}

resource "google_storage_bucket_object" "cloud-function-archive" {
  name   = "cloud-function-archive"
  bucket = google_storage_bucket.cloud-function-bucket.name
  source = "cloud-function.zip" 
}

resource "google_cloudfunctions2_function" "send-email" {
  name        = "send-email"
  location    = "us-central1"
  description = "Function to sending an email"

  build_config {
    runtime     = "python39"
    entry_point = "send_email"
    source {
      storage_source {
        bucket = google_storage_bucket.cloud-function-bucket.name
        object = google_storage_bucket_object.cloud-function-archive.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
  }
  depends_on = [google_project_service.sqladmin_api]
}

resource "google_cloud_run_service_iam_member" "member" {
  location = google_cloudfunctions2_function.send-email.location
  service  = google_cloudfunctions2_function.send-email.service_config[0].service
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "function_uri" {
  value = google_cloudfunctions2_function.send-email.service_config[0].uri
}

resource "google_cloud_scheduler_job" "schedule-send-email" {
  name         = "schedule-send-email"
  description  = "Scheduler for sending email with daily report on the GCP Lyrics App Database"
  schedule     = "0 18 * * *"
  region = "us-central1"
  http_target {
    http_method = "GET"
    uri = google_cloudfunctions2_function.send-email.service_config[0].uri
  }
  depends_on = [google_cloudfunctions2_function.send-email]
}

resource "null_resource" "bootstrap_cloudsql" {
  depends_on = [google_cloudfunctions2_function.send-email]
  provisioner "local-exec" {
    command = <<-EOT
      PROJECT_ID="${var.project_id}"
      REGION="${google_cloudfunctions2_function.send-email.location}"
      SERVICE_NAME="${google_cloudfunctions2_function.send-email.name}"
      CLOUDSQL_CONNECTION_NAME="${google_sql_database_instance.song.connection_name}"
      
      check_cloud_run() {
        gcloud run services list --platform managed --region "$1" --project "$2" --filter "metadata.name=$3" --format "value(metadata.name)" || true
      }
      
      check_cloud_sql() {
        gcloud sql instances list --project "$1" --filter "connectionName:$2" --format "value(connectionName)" || true
      }
      
      check_cloud_sql_added() {
        gcloud run services describe "$1" --platform managed --region "$2" --project "$3" --format "value(metadata.annotations['run.googleapis.com/cloudsql-instances'])" | grep -w "$4" || true
      }
      
      update_cloud_run() {
        gcloud run services update "$1" --platform managed --region "$2" --add-cloudsql-instances "$3" --project "$4"
      }
      
      SERVICE_EXISTS=$(check_cloud_run "$REGION" "$PROJECT_ID" "$SERVICE_NAME")
      if [ -z "$SERVICE_EXISTS" ]; then
        echo "Cloud Run service not found."
        exit 0
      fi
      
      CLOUDSQL_EXISTS=$(check_cloud_sql "$PROJECT_ID" "$CLOUDSQL_CONNECTION_NAME")
      if [ -z "$CLOUDSQL_EXISTS" ]; then
        echo "Cloud SQL instance not found."
        exit 0
      fi
      
      ALREADY_ADDED=$(check_cloud_sql_added "$SERVICE_NAME" "$REGION" "$PROJECT_ID" "$CLOUDSQL_CONNECTION_NAME")
      if [ -n "$ALREADY_ADDED" ]; then
        echo "Cloud SQL instance already added to the Cloud Run service."
        exit 0
      fi
      
      update_cloud_run "$SERVICE_NAME" "$REGION" "$CLOUDSQL_CONNECTION_NAME" "$PROJECT_ID"
    EOT
  }
}